# Overlay system

PocketPilot uses accessibility overlay windows outside MainActivity. The main chat embeds its own controls and hides the floating windows. `OverlayComposeHost` owns the ComposeView and WindowManager lifecycle for every overlay.

## Persistent bubble

`BubbleOverlayHost` and `OverlayBubbleCompose` replace the static status island. The bubble is available over other apps in accessibility and virtual-display modes, including when the agent is idle. Tapping it toggles the current task controls. It remains visible above the expanded controls, so the same bubble can minimize them.

Drag uses absolute screen touch positions and Android's touch-slop threshold to distinguish moving from tapping. Release docks the bubble to the nearest side. The selected side and relative vertical position are saved locally. System-bar and cutout insets bound its position, and configuration changes reposition it within the new display geometry.

New tasks and completed tasks use the minimized bubble. Questions, approvals, and errors open the controls for attention, after which the user may minimize them. The bubble's status color reflects task state. The edge glow is limited to active tasks.

Completed results remain in `CapsuleStateHolder` without an automatic hide timer, including after idle session expiry. Expanded controls show the result as scrollable Markdown, navigation, and a composer. Stopping a session retains a stopped result. The main chat returns directly to its idle composer after completion.

Draft text belongs to the overlay host and survives minimize/expand. Sending while a session exists submits `Op.UserInput`. When a new session is needed, the service holds the user-entered text in memory, opens MainActivity, and hands it to the existing session-creation path. No external-intent confirmation bypass is introduced.

## Capture and touch handling

The bubble, controls, glow, and gesture feedback are temporarily suppressed by the existing screenshot path. Both bubble and controls become untouchable during injected gestures and restore their flags afterward. This lets an agent act at a position occupied by the bubble without toggling its UI.

Expanded accessibility controls may use the existing full-screen interaction shield during automation. The bubble is placed above that window. Minimized controls have no full-screen touch shield. Takeover releases interaction locking while keeping controls available.

**Compact overlays** disables the full-screen shield, edge glow, and gesture visualizer while keeping the bubble and controls. On an OPPO Find X8 running Android 16, those full-screen windows were followed by the device security service revoking accessibility. Compact mode avoids them without changing security settings.

## MainActivity and virtual display

`ServiceOverlayController` treats MainActivity's `onResume` and `onStop` as authoritative. It ignores stale non-self accessibility-window events while MainActivity is resumed. Its hidden callback changes location to another app only when the location was still MainActivity, preserving a concurrently opened virtual-display viewer.

Virtual-display navigation remains available in the expanded controls. Bubble taps only toggle controls and never open a viewer implicitly. The viewer still finishes when its state is Hidden with no active task. Completed and error states retain their controls instead of becoming Hidden automatically.

## Other overlays

- `CapsuleOverlayHost`: focusable text input when idle, done, answering a question, or taking over. Owns its draft and transient confirmation UI.
- `GlowOverlayHost`: task activity feedback, disabled in compact mode and after completion.
- `VisualizerOverlayHost`: tap, long-press, and swipe feedback in complete display coordinates. Hidden when the user is not watching the controlled screen.
- `ServiceLifecycleOwner`: lifecycle and saved-state ownership for service Compose views.

Voice permission requests still use MainActivity's dedicated permission flow. See [voice input](capsule/voice.md). Gesture coordinates and screenshot suppression are described in [phone actions](../infra/tool/phone_actions.md) and [perception](../infra/perception.md).
