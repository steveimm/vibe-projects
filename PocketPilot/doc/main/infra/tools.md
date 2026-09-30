# Tool execution

`DefaultAgentDefinition` lists the agent's tools. `SessionToolingBootstrapper` registers native phone tools. `SessionAgentRunner` connects `ask_user` to the session response channel. Explicit exclusions apply to the model's roster.

| Tool | Purpose |
|---|---|
| `open_app` | Open an installed app by name. |
| `tap`, `long_press`, `swipe`, `type_text` | One gesture or text entry per call. |
| `system_button` | Back, Home, Enter, and Recents. |
| `read_screen` | Inspect the phone when needed, with an optional delay for loading. |
| `ask_user` | Ask for missing information or physical intervention. |

`ToolRouter` resolves the registered tool and validates arguments before creating an invocation. `PolicyEngine` applies app classification, explicit user overrides, approval mode, and session approvals. Blocked apps remain blocked. Back and Home remain available as escape actions. User handoff and other non-screen actions do not acquire screen permissions.

App-access prompts name the package requiring consent. For `open_app`, foreground and destination restrictions are checked separately, so approval for one app cannot cover another. Each prompt has a fresh approval ID; one-call consent prevents repeated prompts while Session or Always consent is recorded.

`TurnExecutionPhaseRunner` records each call and result, executes selected calls sequentially, and captures the resulting screen. The current policy defers completion if the same turn selects a screen action. Tool failure is returned as feedback and must not be treated as successful execution.

There is no delegation, restricted app-process shell, planning tool, memory-writing tool, skill loader, or browser-scripting runtime. Browser tasks use the same phone UI tools as other apps.

See [agent loop](../agent/loop.md), and [session lifecycle](session.md).

See [phone action schemas](tool/phone_actions.md) for coordinates, validation, and serial execution.
