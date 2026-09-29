# Tool execution

`DefaultAgentDefinition` lists the agent's tools. `SessionToolingBootstrapper` registers built-ins and exposes `termux_shell` only when Termux is installed, enabled, and bridge-ready. `SessionAgentRunner` connects `ask_user` to the session response channel. Explicit exclusions apply to the model's roster.

| Tool | Purpose |
|---|---|
| `open_app` | Open an installed app by name. |
| `mobile_action` | Touch, typing, scrolling, and swipe actions. |
| `system_button` | Back, Home, Enter, and Recents. |
| `wait` | Wait for screen updates. |
| `ask_user` | Ask for missing information or physical intervention. |
| `termux_shell` | Optional commands in the Termux workspace. |

`ToolRouter` resolves the registered tool and validates arguments before creating an invocation. `PolicyEngine` applies app classification, explicit user overrides, approval mode, and session approvals. Blocked apps remain blocked. Back and Home remain available as escape actions. User handoff and other non-screen actions do not acquire screen permissions.

`TurnExecutionPhaseRunner` records each call and result, executes selected calls sequentially, and captures the resulting screen. The current policy defers completion if the same turn selects a screen action. Tool failure is returned as feedback and must not be treated as successful execution.

There is no delegation, restricted app-process shell, planning tool, memory-writing tool, skill loader, or browser-scripting runtime. Browser tasks use the same phone UI tools as other apps.

See [Termux](../app/termux_shell.md), [agent loop](../agent/loop.md), and [session lifecycle](session.md).
