# Phone actions

Each new user message starts with conversation context. An overlay task also captures the current app before the first model request, allowing work to start from a screen the user opened manually. The model can answer directly, open an app, or request the screen. It uses at most one tool call per response, or assistant text alone to finish. There is no action selector or semantic target selector.

Gesture feedback uses the same physical display coordinates as injection. A bounded 64 dp window follows the gesture, including near system bars and cutouts, without shifting the marker's center when the window is clamped to an edge.

| Tool | Parameters | Behavior |
| --- | --- | --- |
| `open_app` | `app_name` | Resolve an installed app and launch it |
| `tap` | `point: [x,y]` | Dispatch one gesture tap |
| `long_press` | `point: [x,y]`, optional `duration_ms` | Hold for 1000 ms by default |
| `swipe` | `start: [x,y]`, `end: [x,y]`, optional `duration_ms` | Swipe for 400 ms by default |
| `type_text` | `text` | Replace the focused field's contents; empty text clears it |
| `system_button` | `button`: `back`, `home`, `enter`, `recents` | Press a system key |
| `read_screen` | optional `delay_ms` | Read the current screen, optionally waiting for loading first |
| `ask_user` | `type`, `message` | Request needed information or physical intervention |

Touch coordinates are integers from 0 to 1000 over the full screenshot. Top-left is `(0,0)` and bottom-right is `(1000,1000)`. Execution maps each axis to `round(coordinate / 1000 × (displayDimension − 1))`, independent of screenshot resizing. A missing screenshot or changed aspect ratio rejects the gesture. Long presses and swipes accept durations from 100 to 3000 ms. Screen reads accept a delay from 0 to 30000 ms, defaulting to 0.

Taps and text entry require a current screenshot. The caller must tap a field before typing. A tool success means Android accepted the action; the model must inspect the next screenshot to verify the result. Gesture calls do not choose semantic nodes, retry different target formats, or reinterpret pixel coordinates.

`parallel_tool_calls=false` requests serial calls. If a response still contains multiple calls, all are rejected before execution and each receives a correlated error. Invalid JSON, unavailable tools, missing fields, wrong types, unknown fields, enums, and numeric bounds produce explicit feedback. The runtime never executes malformed arguments as an empty default call.

App-access policy and cancellation apply to every action. `back` and `home` remain available to leave blocked apps.

A held overlay bubble delays dispatch. Dragging requests takeover and blocks queued actions, including actions waiting in the execution or gesture setup delays. The bubble stays touchable and moves clear of overlapping strokes. Compact panels pass through only intersecting strokes; the optional full-screen touch shield passes through every injected stroke. A panel that cannot receive touches is hidden for that lease. See [overlay behavior](../../ui/overlay.md#capture-and-touch-handling).

Owners: `TouchTools.kt`, `ToolParameters.kt`, `ToolRouter.kt`, `Turn.kt`, and `TurnExecutionPhaseRunner.kt`.

Each point must contain exactly two integers. Validation returns all issues together and includes a canonical example for gesture calls. Invalid arguments never become executable coordinates through coercion or guessing.

Tool errors return to the model as tool results. After six turns with tool errors in one request, the model gets one final response with tools disabled to explain verified progress and the blocker. Successful reads do not reset that budget. Transport failures and user cancellation keep their separate handling.
