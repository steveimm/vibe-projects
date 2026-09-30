# UI style

PocketPilot uses cool neutral surfaces, a blue accent, and Geist typography. The interface is minimal: one logo in the chat header, compact controls, and text that explains an action or state. Do not add slogans, decorative hero sections, repeated labels, or helper copy that merely restates a field's label.

## Theme ownership

| Source | Responsibility |
|---|---|
| `ui/theme/Color.kt` | Light and dark semantic colors |
| `ui/theme/Theme.kt` | Material roles, foreground defaults, system bars |
| `ui/theme/Type.kt` | Geist text and JetBrains Mono code/metadata |
| `ui/theme/Shape.kt` | Shared Material corner radii |
| `ui/theme/Tokens.kt` | Spacing and additional text/color tokens |
| `ui/theme/Motion.kt` | Durations, easing, observable reduced-motion preference |
| `ui/theme/AppHeaders.kt` | Plain page headers and section titles |
| `ui/common/PilotMark.kt` | Shared vector navigation mark |

Use semantic Material colors. Blue identifies primary actions, green indicates finished or enabled states, amber indicates paused or stopped states, and red indicates errors. A finished task does not assert that its goal was verified.

The navigation mark appears in the launcher, chat header, and floating bubble. Settings and setup use plain headers. Do not repeat the logo inside the empty chat or use it as a progress indicator.

## Layout

The empty chat contains compact editable suggestions above the composer. Tapping one fills the input without submitting it. Allow unused space to remain empty.

Use a single activity disclosure for reasoning and tool actions. Keep the current answer outside that disclosure. Show task progress once in the control panel. Use error messages where recovery is possible, and keep the composer available after a task fails.

Settings uses a short list of destinations. Subtitles describe current state only when useful. The model-server form contains the endpoint, optional key, connection test, model ID/selector, and save action. Keep authentication, connection failures, and deferred configuration changes clear without extra explanation.

Controls must remain usable with larger text, landscape orientation, and a keyboard. Use scrolling and wrapping for constrained layouts. Maintain at least a 48 dp touch target for interactive controls.

## Motion

Use the shared short transitions for settings navigation, setup, and activity disclosure. The floating panel fades and translates slightly. Dragging follows the finger, and release animates to the selected edge. Respect Android's animation preference and stop decorative loops when animations are disabled.

Overlay animation and screenshot hiding must have separate owners. `OverlayComposeHost` hides its outer container for screenshots while animating its content view. Gesture markers are never translated by the panel animation.
