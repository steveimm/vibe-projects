# Development Guide

> Last updated: 2026-05-12 (release-prep wave 2: signing pipeline, R8 unblock, GitHub release workflow)

This guide covers the development workflow for PocketPilot - building, testing, and debugging.

## Debug vs Release APK — always debug unless shipping

All day-to-day work uses the **debug** APK. The **release** APK is only for shipping, release smoke tests, or APK-size / cold-start measurements. Do **not** drive eval, autotune, UX QA, or `debug-run.sh` against a release build.

| | Debug | Release |
|---|---|---|
| Build | `./gradlew assembleDebug` (seconds) | `./scripts/release-build.sh :app:assembleRelease` (~2 min) |
| Install | `scripts/setup.sh`, `adb install -r …` | Sign then `adb install`. `scripts/setup.sh` targets debug. |
| R8 / resource shrink | off | **on** (`isMinifyEnabled=true`, `isShrinkResources=true`) |
| `BuildConfig.DEBUG` | `true` → `LlmLogger.VERBOSE_LOGGING` prints full prompt/response; streaming clients build accumulators | `false` → verbose log off, accumulators skipped (see `perf-streaming-guard`) |
| `INSECURE_SSL_FOR_EVAL` | opt-in via `-PinsecureSslForEval=true` | forced `false` |
| Custom HTTP endpoints | Supported for configured custom servers and localhost tools | Supported for configured custom servers and localhost tools |
| Stack traces | non-obfuscated | obfuscated by R8 (use `app/build/outputs/mapping/release/mapping.txt` to deobfuscate) |

**When to build release:**
1. Release artifact / public distribution.
2. Validating R8 keep rules (`app/proguard-rules.pro`). After any SDK upgrade or reflection/AIDL touch, run `./scripts/release-build.sh :app:assembleRelease` and grep `app/build/outputs/mapping/release/mapping.txt` for any symbol expected to stay unobfuscated.
3. Measuring APK size, cold start, or dex method count.

### Signed release builds (`scripts/release-build.sh`)

`./gradlew assembleRelease` direct doesn't sign — `signingConfigs.create("release")` reads keystore env vars (`KEYSTORE_PATH/KEYSTORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD`) and gracefully falls back to `null` when they're absent (so IDE syncs don't break). The wrapper script validates that these env vars are present before shipping:

- Keep the keystore and password outside the repo, with owner-only permissions.
- Export `KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and `KEY_PASSWORD` in a trusted shell before running `scripts/release-build.sh`.
- New maintainer onboarding: get release signing material through a private credential handoff, or generate a fresh keystore for personal/dev work. `.gitignore` covers `*.keystore` `*.jks` `*.password`, but the canonical boundary is outside the repo.
- CI publishes via `.github/workflows/release.yml` (fires on `v*` tag push; reads `KEYSTORE_BASE64` + `KEYSTORE_PASSWORD` from GitHub Secrets).

**R8 keep-rule pitfalls already handled** (in `app/proguard-rules.pro` + `app/build.gradle.kts`):
- snakeyaml (direct dep, `SkillFrontmatterParser`) calls `java.beans.*` which Android lacks → `-dontwarn java.beans.**` + `-keep org.yaml.snakeyaml.**`.
- `bcprov-jdk18on:1.84` ships Java-25 multi-release bytecode that Kotlin 2.3.0's `produceReleaseComposeMapping` ASM can't parse → that whole optional pipeline (`produce/merge/reportReleaseComposeMappingErrors`) is disabled in `afterEvaluate`. Only debug-only stack-trace metadata is lost; APK functionality unaffected.
- R8 needs `-Xmx4096m` daemon heap (`gradle.properties`); 2 GB OOMs.

**Before publishing a release:** install the signed release APK with the configured model server and run at least one full LLM tool-call end-to-end. R8 is the likely source of any `ClassNotFoundException` / `NoSuchMethodError`, and the `ChatCompletionClient` streaming paths are the highest-risk zones. The `perf-qa-real-device` QA report explicitly calls this out as a follow-up.

## Prerequisites

- Android device or emulator with USB debugging enabled
- ADB installed and accessible
- A reachable OpenAI-compatible Chat Completions server and its model ID

## Quick Start

### Using your model server

Configure Settings → Model server in the app, or use host environment values for debug/evaluation runs:

```bash
export POCKETPILOT_SERVER_URL=http://192.168.1.10:8000/v1
export POCKETPILOT_MODEL_ID=my-model
# Set POCKETPILOT_API_KEY only if your server requires one.
./scripts/debug-run.sh "Open Settings"
```

The phone must be able to reach the supplied address. Use the computer's LAN or VPN address for a physical phone. Android emulators reach their host at `10.0.2.2`.

## Development Cycle

The typical development loop:

```
Code change → Build & Deploy → Unit Tests → Device Test → View Logs → Debug
```

### 1. Build & Deploy

After any code change, run setup to build, install, and configure permissions:

```bash
./scripts/setup.sh
```

This handles everything: build APK, install, grant permissions, enable accessibility, launch app.

> `debug-run.sh` now invokes `setup.sh` as a preflight on every run, so the typical loop is just `./scripts/debug-run.sh ...` — the preflight is idempotent and fast when the APK is up-to-date and permissions are already granted. The standalone `./scripts/setup.sh` invocation above is for first-install or when you want the explicit build/perms pass without firing an agent goal.

### 2. Unit Tests (JVM)

Run the local JVM test suite after code changes:

```bash
./gradlew test
```

For faster iteration, run a single test class:

```bash
./gradlew test --tests "id.steveimm.pocketpilot.history.HistoryManagerTest"
```

### 2b. Compose UI Tests (instrumented, on device/emulator)

Behavior-guard tests for app-owned UI live under `app/src/androidTest/kotlin/id/steveimm/pocketpilot/qa/`. They run on a connected device or emulator via `AndroidJUnitRunner` + Compose UI Test, with `animationsDisabled=true` to prevent flake.

```bash
adb devices                                                                    # confirm device attached
./gradlew connectedDebugAndroidTest \
    -Pandroid.testInstrumentationRunnerArguments.package=id.steveimm.pocketpilot.qa
```

What is and isn't covered:

- `app/src/test/` — fast JVM unit tests (logic, state, formatting).
- `app/src/androidTest/kotlin/id/steveimm/pocketpilot/qa/` — Compose UI behavior guards across Chat, SmartCapsule, Settings (45 tests as of 2026-04-17). Layout is flat, files grouped by area (`ChatHeaderTest`, `CapsuleInputTest`, `SettingsNavTest`, ...). No Robot pattern, no annotations, no base classes.
- `eval/` — AndroidWorld-style agent benchmarks (separate Python harness, see `/autotune`).

Design rule: add tests when adding behavior or fixing bugs — don't wait for bugs to grow guards.

Critical pitfall: **never use Kotlin built-in `assert(...)` for verdicts** in androidTest — it's a no-op without `-ea` and silently passes. Use `org.junit.Assert.assertTrue` / `assertEquals` or Compose's `onNode(...).assertExists()` / `assertCountEquals(...)`.

### 2c. Browser Runtime Tests

### Prompt Ownership

When tuning the agent's cognition, edit the narrowest owner:

- Core cross-tool behavior: `agent/definition/DefaultAgentDef.kt` (the session agent prompt)
- Tool-local semantics: tool `description` strings in `tool/impl/*.kt`
- App-specific guidance: `app/src/main/assets/app_skills/<package>/SKILL.md`

The active app skill is loaded fresh each turn from the foreground package and inserted into the
prompt between Working Memory and Observation.

### 3. Device Test

Run the agent with a goal. `debug-run.sh` captures screenshots at each turn, records trace artifacts, and saves comprehensive logs for post-run analysis. Press Ctrl+C to gracefully stop the agent.

> Onboarding bypass: debug builds skip the onboarding wizard whenever the launch intent carries both `fresh_session=true` and a `goal` extra (handled in both `onCreate` and `onNewIntent` of `MainActivity`). `debug-run.sh` always sets these, so you never need to complete the wizard before iterating.

```bash
./scripts/debug-run.sh "Open Settings"                        # Uses your configured model server
./scripts/debug-run.sh --main-model gpt-5.2 "Open Chrome"     # Override main model
./scripts/debug-run.sh --perception accessibility_only "Open Chrome" # Explicit perception mode
./scripts/debug-run.sh --accessibility-only "Open Chrome"     # A11y only
./scripts/debug-run.sh --screenshot-only "Open Chrome"        # Screenshot only
./scripts/debug-run.sh --hybrid "Open Chrome"                 # A11y + screenshot
./scripts/debug-run.sh --virtual-display "Open Chrome"        # Run on Shizuku virtual display
```

Output in `debug-output/run_<timestamp>/`:
- `turn_NNN_n<turn>.png` - Screenshot at each captured turn-start
- `turn_NNN_n<turn>_log.txt` - Log excerpt around that turn
- `logcat_full.log` - Raw logcat stream
- `agent.log` - Filtered agent log
- `system.log` - Filtered system/service log
- `trace/` - JSONL trace + replay artifacts

See [Visual Debug Guide](visual_debug_guide.md) for systematic debugging workflow.

### 3.1 Direct Action Debug (Execution Layer)

Use `action-test.sh` to isolate action execution outside the full agent loop:

```bash
./scripts/action-test.sh click --x 540 --y 1200
./scripts/action-test.sh scroll --direction down
./scripts/action-test.sh long_press --x 540 --y 800 --duration 1500
./scripts/action-test.sh click --x 540 --y 1200 --compare   # ADB baseline vs a11y path
./scripts/action-test.sh tap --x 540 --y 1200 --shizuku --display-id 0
```

This is useful when a gesture tool reports success but UI does not change.

### 3.2 Direct MobileActionTool Debug (Tool Pipeline)

`action-test.sh` exercises the platform layer directly; `mobile-action-test.sh` exercises the **full tool pipeline** — `MobileActionTool.validate → createInvocation → TargetResolver → executor → AccessibilityPlatform`. Use it when you need deterministic dual-target shapes the LLM cannot reliably emit (e.g. `element_index + x/y outside bounds` to verify `Ambiguous` failure):

```bash
./scripts/mobile-action-test.sh '{"action":"click","element_index":28,"x":632,"y":1844}'
./scripts/mobile-action-test.sh '{"action":"click","element_index":28,"x":99999,"y":99999}'  # Ambiguous
./scripts/mobile-action-test.sh '{"action":"click","element_index":9999,"x":632,"y":1844}'  # coordinate fallback
```

Backed by `MobileActionDebugRunner` — a debug-only (`BuildConfig.DEBUG`) `BroadcastReceiver` registered in `AgentService`. Writes `result.json` + `pre_tree.json` + `post_tree.json` to `/sdcard/Android/data/id.steveimm.pocketpilot/files/mobile-action-debug/latest/`.

### 4. View Logs

Monitor agent behavior through filtered logs:

```bash
./scripts/logs.sh                # All agent logs
./scripts/logs.sh orch           # Orchestration flow
./scripts/logs.sh llm            # LLM API calls
./scripts/logs.sh action         # Action execution
```

## Configuration

### Model server

Use `POCKETPILOT_SERVER_URL`, `POCKETPILOT_MODEL_ID`, and optional `POCKETPILOT_API_KEY` in `.env` or the environment. `debug-run.sh` forwards configured values through debug-only intent extras. Without those overrides, configure the server in the app first.

Both debug and release builds support explicit HTTP server URLs. HTTPS retains certificate verification. The model ID is the server's actual ID, not a key from a bundled cloud catalog.

### Remote Eval Helper Config

The remote helper scripts read optional machine-local settings from `.pocketpilot-local.env`.
Copy `.pocketpilot-local.env.example` to `.pocketpilot-local.env` and edit it for your machines:

```bash
cp .pocketpilot-local.env.example .pocketpilot-local.env
```

`scripts/remote/sync.sh` and `scripts/remote/scrcpy.sh` use `POCKETPILOT_REMOTE` and
`POCKETPILOT_REMOTE_DIR`. `scripts/remote/proxy_tunnel.sh install` uses
`POCKETPILOT_PROXY_HOST`, `POCKETPILOT_PROXY_USER`, and `POCKETPILOT_PROXY_PORT`, then writes the
systemd user service env file at `~/.config/pocketpilot/proxy-tunnel.env`.

### Perception Mode

```bash
# one-off
./scripts/debug-run.sh --accessibility-only "Open Settings"
./scripts/debug-run.sh --screenshot-only "Open Settings"
./scripts/debug-run.sh --hybrid "Open Settings"
./scripts/debug-run.sh --perception screenshot_only "Open Settings"

# persistent default
echo 'PERCEPTION_MODE=hybrid' >> .env
```

| Mode | Behavior |
|------|----------|
| `accessibility_only` (default) | Accessibility tree only |
| `hybrid` | Accessibility tree + screenshot |
| `screenshot_only` | Screenshot only |

### Platform Mode

Control which platform implementation is used:

```bash
# one-off
./scripts/debug-run.sh --virtual-display "Open Settings"
./scripts/debug-run.sh --vd "Open Settings"

# persistent default
echo 'PLATFORM_MODE=virtual_display' >> .env
```

| Mode | Behavior |
|------|----------|
| `accessibility` (default) | Standard operation on main display |
| `virtual_display` | Runs agent on a private virtual display (requires Shizuku) |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "App not installed" | Run `./scripts/setup.sh` |
| "Accessibility service not enabled" | Run `./scripts/setup.sh`, or enable manually in Settings |
| "No device detected" | Check USB debugging, run `adb devices` |
| Agent not responding | Run `./scripts/setup.sh`, then check `./scripts/logs.sh` |
| `ClassNotFoundException` / `NoSuchMethodError` only on release | Missing R8 keep rule — open `app/proguard-rules.pro`, add a targeted keep for the offending package/class, rebuild. Debug build won't reproduce. |
| Verbose prompt/response log missing | You are running release. Switch to debug — `VERBOSE_LOGGING = BuildConfig.DEBUG`. |

## Worktrees

This repo uses git worktrees for isolated task branches (e.g., orchestrate's `.worktrees/<slug>/`). Two per-machine files — `.env` (LLM credentials) and `local.properties` (Android SDK path) — are gitignored and must be present in every worktree for `./gradlew` and `scripts/debug-run.sh` to work.

`scripts/worktree-provision.sh` handles this automatically: the orchestrate skill's `worktree-create.sh` runs it once when a worktree is first created, symlinking `.env` and `local.properties` from the main checkout. It's idempotent — safe to re-run manually if a worktree is ever reset or missing the links.

## Detailed Documentation

- **[Scripts README](../../scripts/README.md)** - Complete script reference and options
- **[Visual Debug Guide](visual_debug_guide.md)** - Step-by-step debugging methodology

## Evaluation Harness

-> See: `eval/README.md` for full reference, `doc/main/eval/eval.md` for architecture.

```bash
# Quick start
eval/.venv/bin/python eval/aw_bridge/runner.py --tasks-file eval/config/aw_subset_smoke.txt
eval/.venv/bin/python eval/aw_bridge/runner.py --tasks "TaskA,TaskB"

# Setup-only for one task (no agent run)
eval/.venv/bin/python eval/aw_bridge/setup_task_only.py --task FilesMoveFile
```

Use `eval/.venv/bin/python` for eval commands. Config override files are deep-merged on top of `eval/config/default.yaml`.

## Inspection Tool (Replay v2)

Web-based trace viewer: from `inspection_tool/`, run `uv run uvicorn server:app --reload` → [http://localhost:8000](http://localhost:8000). Step-by-step replay with screenshots, a11y trees, tool calls, and token stats. See `inspection_tool/README.md`.
