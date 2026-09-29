# Phone actions

The model receives a screenshot and calls one tool per response. There is no action selector or semantic target selector.

| Tool | Parameters | Behavior |
| --- | --- | --- |
| `open_app` | `app_name` | Resolve an installed app and launch it |
| `tap` | `x`, `y` | Dispatch one gesture tap |
| `long_press` | `x`, `y`, optional `duration_ms` | Hold for 1000 ms by default |
| `swipe` | `start_x`, `start_y`, `end_x`, `end_y`, optional `duration_ms` | Swipe for 400 ms by default |
| `type_text` | `text` | Replace the focused field's contents; empty text clears it |
| `system_button` | `button`: `back`, `home`, `enter`, `recents` | Press a system key |
| `wait` | optional `duration_ms` | Wait 1000 ms by default and observe again |
| `ask_user` | `type`, `message` | Request needed information or physical intervention |

Touch coordinates are integers from 0 to 1000 over the full screenshot. Top-left is `(0,0)` and bottom-right is `(1000,1000)`. Execution maps each axis to `round(coordinate / 1000 × (displayDimension − 1))`, independent of screenshot resizing. A missing screenshot or changed aspect ratio rejects the gesture. Long presses and swipes accept durations from 100 to 3000 ms. Wait accepts 0 to 30000 ms.

The caller must tap a field before typing. A tool success means Android accepted the action; the model must inspect the next screenshot to verify the result. Gesture calls do not choose semantic nodes, retry different target formats, or reinterpret pixel coordinates.

`parallel_tool_calls=false` requests serial calls. If a response still contains multiple calls, all are rejected before execution and each receives a correlated error. Invalid JSON, unavailable tools, missing fields, wrong types, unknown fields, enums, and numeric bounds produce explicit feedback. The runtime never executes malformed arguments as an empty default call.

App-access policy and cancellation apply to every action. `back` and `home` remain available to leave blocked apps. The optional `termux_shell` tool keeps its separate bridge contract.

Owners: `TouchTools.kt`, `ToolParameters.kt`, `ToolRouter.kt`, `Turn.kt`, and `TurnExecutionPhaseRunner.kt`.
