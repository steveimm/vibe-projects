# PocketPilot

AI-powered Android automation using accessibility services. Kotlin/Jetpack Compose.

## Quick Reference

**APK deliverable**: Signed release for `arm64-v8a` only, using the existing signing key.
**Development build**: `./gradlew assembleDebug` (only when required for development or device tests)
**Test (JVM)**: `./gradlew test`
**Test (Compose UI on device)**: `./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.package=id.steveimm.pocketpilot.qa`
**Lint**: `./gradlew lint`
**Run**: `./scripts/debug-run.sh "Open Settings"`
**Full Check**: `./gradlew clean assembleDebug lint test`

**Architecture Docs**: `doc/main/`
**Dev Workflow**: `doc/dev/development.md`
**Termux Shell**: `termux_shell` joins the agent tool roster when F-Droid Termux is installed, enabled, and bridge-ready. See `doc/main/app/termux_shell.md`.
**Private workspace**: if `projects/` exists locally, treat it as ignored private agent state / artifacts. Do not link it from public repo docs.

## Critical Rules

Project-specific additions:

- Lifecycle-aware: no static Context refs, scope coroutines to lifecycle
- Main-safe: heavy work on `Dispatchers.IO` or `Default`
- Accessibility: follow service best practices, handle edge cases
- Sanitize accessibility tree data
- Image reads: before using `view_image` on local screenshots, video frames, or montages, first downscale/compress to a small JPEG/PNG thumbnail. Do not open large raw captures directly; oversized image payloads can make the LLM API reject the request with 413 Payload Too Large.

## Project Agent Skills

- `/autotune` - One eval-tune round, stops for human review
- `/autotune-loop` - Autonomous multi-round autotune via `loop_state.json`
- `/prompt-tune` - Apply prompt, tool, and app-skill changes per ownership layer
- `/build-fix` - Fix Gradle errors incrementally
- `/action-debug` - Debug failed tool executions by isolating action layer
- `/cog-tune` - Analyze agent cognition using traces and eval results
- `/ux-visual-debug` - End-to-end UX QA from user perspective via ADB

## Code conventions

- Prefer straightforward control flow and reuse existing helpers before adding abstractions.
- Keep related behavior together. Extract a module when it removes duplication or gives one responsibility a clear owner.
- Keep comments necessary and at most two lines. Put longer explanations in `doc/`.
- Preserve coroutine cancellation. Run blocking work on IO and release resources on every exit path.
- Use typed Python parameters and return values, concise Google-style function docstrings, and no module docstrings.
- Prefer 120–140 character lines and one blank line between logical sections.
- Use the CLI for dependency changes. Test behavior and failure boundaries, not implementation details.

## Git

Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`
