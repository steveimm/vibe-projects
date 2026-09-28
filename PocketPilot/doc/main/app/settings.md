# Settings & Configuration

> User settings, preferences, and configuration persistence.
> Last updated: 2026-05-20 (approval mode selector, settings reorder, copy audit)

## Model server settings

`AppSettingsState` exposes one immutable settings snapshot to Compose. `AppSettingsStore` saves the server URL and model ID together in ordinary preferences. `ServerCredentialStore` keeps the optional API key in encrypted preferences, scoped to the normalized server URL.

| Setting | Default | Purpose |
|---------|---------|---------|
| `serverBaseUrl` | Empty | Explicit HTTP(S) API base URL |
| `serverModelId` | Empty | Exact model ID served by that endpoint |

Settings → Model server and onboarding share `ModelServerForm`. A model can be entered manually or selected from the endpoint's optional `/models` response. Saving requires a URL and model ID, but does not require an API key or a successful discovery request.

Previously saved custom-server fields migrate to the new settings. Built-in cloud selections do not migrate. A key is never reused for a different endpoint. See [Model server](../infra/llm.md) for transport and session ownership.

`SettingsToggleGate` controls Browser Script and Virtual Display permission checks. Turning a toggle off cancels a pending attempt so a late permission result cannot enable it again.

### Approval

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `approvalMode` | `ApprovalMode` | `SMART` | `SMART` (Per-App: ask for CAUTIOUS apps), `AUTO_APPROVE` (skip approval for non-BLOCKED apps). `ALWAYS_ASK` is deprecated and normalized to `SMART` on load. |

→ See: [infra/tools.md](../infra/tools.md) → PolicyEngine for the full decision matrix per mode × tier.

### Execution

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `debugMode` | `Boolean` | `false` | Verbose logging + debug artifacts |
| `browserScriptEnabled` | `Boolean` | `false` | Enables `browser_script` execution gate |
| `termuxShellEnabled` | `Boolean` | `true` | Allows `termux_shell` exposure when Termux is installed and bridge-ready |

There is no Max Turns setting. Production runs are bounded by context-window
auto-compaction (see [agent/loop.md](../agent/loop.md#auto-compaction)), not by a
turn count. The eval bridge has its own `eval_turn_budget` safety net wired
through `SessionConfig.evalTurnBudget` (`null` in production).

### Platform

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `platformMode` | `PlatformMode` | `ACCESSIBILITY` | `ACCESSIBILITY` (standard) or `VIRTUAL_DISPLAY` (Shizuku-based) |

> See: [infra/platform.md](../infra/platform.md) for `VirtualDisplayPlatform` and `PlatformFactory` details.

### Perception

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `perceptionMode` | `String` | `"accessibility_only"` | One of: `accessibility_only`, `screenshot_only`, `hybrid` |

> See: [infra/platform.md](../infra/platform.md) for `PerceptionConfig` variants and capture behavior.

---

## SessionConfig Compilation

> See: `protocol/SessionConfig.kt`

Settings are compiled into `SessionConfig` when creating a session:

```kotlin
data class SessionConfig(
    val actionDelayMs: Long = 2000,
    val approvalMode: ApprovalMode = ApprovalMode.SMART,
    val llm: SessionLlmConfig = SessionLlmConfig(baseUrl = "http://server:8000/v1"),
    val mainModel: String = "my-model",
    val perceptionConfig: PerceptionConfig = PerceptionConfig.DEFAULT,
    val platformMode: PlatformMode = PlatformMode.ACCESSIBILITY,
    val evalTurnBudget: Int? = null,   // eval-only safety net
    // ...
)
```

- `perceptionConfig` is built from `perceptionMode` string: `accessibility_only` → `AccessibilityOnly`, `screenshot_only` → `ScreenshotOnly`, `hybrid` → `Hybrid`
- Child agents inherit the configured server and main model
- `platformMode` selects `AndroidPlatform` implementation via `PlatformFactory`

---

## Settings UI

> See: `ui/settings/SettingsSheet.kt`

The settings UI is a full-screen page overlay with sub-page navigation (system back: sub-page → HOME, HOME → dismiss). The HOME page groups entries into three sections:

| Section | Entry | Destination |
|---------|-------|-------------|
| **Behavior** | Model server | `ModelServerSettingsPage` with URL, model ID, and optional API key |
| | Agent Behavior | `AgentBehaviorSettingsPage` — Approval (Per-App / Auto-Approve selector + App Access Rules link), Perception, Display Mode, Tools |
| | Memory | `MemorySettingsPage` — User Memory + Device Memory editors (per-app memory lives under App Access) |
| **Access** | App Access | `AppAccessSettingsPage` — per-app classification (Allow/Ask/Reject) + inline skill viewer + bounded memory editor. Shows Auto-Approve warning banner when that mode is active. |
| | System & Debug | Accessibility / Overlay status, debug, trace, version |
| **About** | Open Source Licenses | Runtime dependencies and licenses generated into `assets/open_source_licenses.json` and rendered by `OpenSourceLicensesPage` |

The HOME page subtitle for Agent Behavior reflects the active approval mode label ("Per-App" or "Auto-Approve"), perception mode, and display mode. The navigation drawer uses `Lucide.SlidersHorizontal` for the Settings icon.

### Memory Page

> See: `ui/settings/MemorySettingsPage.kt`, `ui/settings/MemoryFileEditor.kt`, `ui/settings/MemoryFileEditorPage.kt`

The Memory page lists two navigation rows — **User Memory** and **Device Memory** — that push a full-screen `MemoryFileEditorPage`. Per-app memory is not listed here; the user reaches it from App Access (an installed app implies an editor location, and Memory does not list packages with no override).

`MemoryFileEditor` is the reusable composable behind both the standalone page and the App Access expansion. Two variants:

- **unbounded** (`bounded = false`) — fills the page. Used by `MemoryFileEditorPage` and the standalone Memory page rows.
- **bounded** (`bounded = true`) — height capped at 240.dp with internal scroll. Used inside the App Access inline expansion. Renders an `↗ Open` affordance (disabled while the buffer is dirty to avoid a double-buffer race with the full-page editor).

Both variants observe `MemoryEditGate.memoryEditLocked` (see [memory.md → MemoryEditGate](../agent/memory.md#single-writer-model-memoryeditgate)). When locked: Save / Discard / Delete disable, a banner reads *"Session is open. Stop the session to edit memory."*, and the typed buffer is preserved (the user is not popped out of EDIT mode). Every save / delete handler re-checks `gate.memoryEditLocked.value` inside the coroutine immediately before calling `MemoryStore.write` / `delete` to close the click-to-IO TOCTOU window; if it lost the race, the write aborts with a toast and the file on disk is untouched.

### App Access — inline expansion

> See: `ui/settings/AppAccessSettingsPage.kt`, `ui/settings/AppRowExpansion.kt`, `ui/settings/AppAccessContentIndex.kt`

Each App Access row collapses by default to the package's display name + tier selector + content chips. Chips show **Skill** when the package has a bundled `app_skills/<pkg>/SKILL.md`, **Memory** when `apps/<pkg>.md` exists, and a **+ Memory** affordance when neither applies (gate-aware: disabled and inert while `memoryEditLocked` is true).

Tapping a row toggles `AppRowExpansion`:

- **Read-only App Skill viewer** when the package ships a bundled skill — bounded scroll, body loaded lazily on `Dispatchers.IO` via `AssetAppSkillRepository`.
- **Bounded `MemoryFileEditor`** for `apps/<pkg>.md` when either a memory file already exists or the user just created one via `+ Memory`. The editor sets `scope = MemoryScope.APP, packageName = pkg`.
- **Blocked-app warning chip** above the editor when the package is in the `BLOCKED` tier. The inline editor is intentionally **not** disabled — a Settings edit is the user's explicit consent (the agent-side write gate exists to require this consent, not to be redundant with it). The warning makes the consequence explicit: *"Reject only blocks the agent from writing this memory; saved entries are still recalled when this app is foreground."*

The `+ Memory` chip routes through a coroutine that:

1. Re-checks `gate.memoryEditLocked.value` (UI-level disabling can race the lock flipping mid-recomposition; the launch-time re-check is the source of truth).
2. Re-reads via `memoryStore.read(MemoryScope.APP, pkg)`. If the file already exists (stale index, or a double-tap raced), it skips the write so an existing `apps/<pkg>.md` is **never blanked**.
3. Otherwise calls `memoryStore.write(MemoryScope.APP, pkg, "")` and inspects the `SaveResult`. On `Success`, it updates the page-scoped `AppAccessContentIndex` (no filesystem rescan), expands the row, and seeds a per-package one-shot nonce so the editor lands directly in **EDIT** mode rather than VIEW.
4. On a lock-race abort, shows the standard memory toast (*"Memory edit aborted — a session just started."*).

`AppAccessContentIndex` is a page-scoped preload that drives the chips in O(1). It builds a `Map<package, AppContentSummary(hasMemory, hasSkill)>` once on mount via a `Mutex`-serialized `load()` on `Dispatchers.IO`, merging `MemoryStore.listAppPackages()` with the parsed `app_skills/` asset tree (filtering to entries whose `SKILL.md` parses cleanly via `SkillFrontmatterParser`, matching the gating used by `AssetAppSkillRepository`). Save / delete inside the inline editor calls `index.update(pkg, summary)` to keep the chip current without re-scanning. The same mutex serializes `load()` with `update()` so an in-flight scan cannot clobber a row-level update.

### Agent Behavior → Approval

> See: `ui/settings/AgentBehaviorSettingsPage.kt`

The Approval section sits at the top of the Agent Behavior page. A `SegmentChip` selector offers two modes:

- **Per-App** (`SMART`) — Ask before risky actions, based on each app's access rules. A nested "App Access Rules" navigation row links to the App Access page.
- **Auto-Approve** (`AUTO_APPROVE`) — Run allowed actions without asking. Rejected apps stay blocked.

`ALWAYS_ASK` is deprecated: `AppSettingsStore.load()` normalizes it to `SMART` so the UI never encounters a mode with no chip.

Cross-page hints: when Auto-Approve is active, `AppAccessSettingsPage` shows a `SettingsAlertCard` warning that per-app rules only apply in Per-App mode. When Per-App is active, the Approval card embeds an "App Access Rules" link.

### Agent Behavior → Tools

> See: `ui/settings/AgentBehaviorSettingsPage.kt`, `ui/settings/ToolsSection.kt`, `ui/settings/AgentSkillToggleRows.kt`

The Tools section now hosts both capability toggles and **per-skill enable/disable rows** sourced from the bundled + installed Agent Skill catalog:

- Each row shows the skill name, a Switch (ON = enabled), and an info icon. Info opens a dialog viewer with the full SKILL.md body (frontmatter stripped, matching what the model would see).
- The switch is mirrored to `AppSettingsStore.disabledAgentSkills`: ON ⇔ NOT in the disabled set. Writes go through `setSkillDisabled(name, disabled)` which is `Mutex`-serialized so rapid toggles cannot race the read-modify-write on the prefs commit.
- **Activation is at session creation.** `AgentSkillManager` snapshots the disabled set at construction time inside `SessionServices.create`. When a session is running and a skill is disabled in Settings, the row's subtitle reads *"Takes effect next session"* — the persisted state is committed, but the current session continues to see the skill.
- On first composition the rows install bundled Agent Skills via `SessionServices.installBundledAgentSkills` on `Dispatchers.IO`, so opening Settings before any session has run still discovers the bundled catalog.

See [agent_skills.md → Disable filter (next-session semantics)](../agent/agent_skills.md#disable-filter-next-session-semantics) for the runtime side.

## Persistence

Ordinary settings use `agent_prefs`. The model configuration is stored in `server_base_url` and `server_model_id`. Trace, perception, approval, app access, platform, and compact-overlay settings retain their existing keys.

Optional keys use encrypted `auth_store` preferences, indexed by a hash of the normalized endpoint. Blank values explicitly clear authentication for that endpoint. Keys from old built-in providers are never selected. The previous custom-server key is imported only for its matching legacy URL.

The onboarding `step_api_key` key remains solely as the storage name for the model-server step outcome. Live server configuration is still required before advancing. Settings deep links point directly to `MODEL_SERVER` without provider tabs.
