# Overlay system

PocketPilot uses accessibility overlay windows outside MainActivity. The main chat embeds its own controls and hides the floating windows. `OverlayComposeHost` owns the Compose controls and bubble. `EffectWindow` owns the small non-interactive indicator windows.

## Persistent bubble

`BubbleOverlayHost` and `OverlayBubbleCompose` replace the static status island. The bubble is available over other apps in accessibility and virtual-display modes, including when the agent is idle. Tapping it toggles the current task controls. It remains visible above the expanded controls, so the same bubble can minimize them.

Drag uses absolute screen touch positions and Android's touch-slop threshold to distinguish moving from tapping. Release docks the bubble to the nearest side. The selected side and relative vertical position are saved locally. System-bar and cutout insets bound its position, and configuration changes reposition it within the new display geometry.

New tasks use the minimized bubble. Completion and session expiry preserve the user’s expanded/minimized choice. Questions, approvals, and errors open the controls for attention, after which the user may minimize them. The bubble's status color reflects task state. The edge glow is limited to active tasks.

Completed results remain in `CapsuleStateHolder` without an automatic hide timer, including after idle session expiry. Expanded controls show the result as scrollable Markdown, navigation, and a composer. Stopping a session retains a stopped result. The main chat returns directly to its idle composer after completion.

The service state holder owns shared task/note and question-answer drafts. They survive minimizing and switching to chat. A new question clears only its answer draft. Sending while a session exists submits `Op.UserInput`. When a new session is needed, the service holds the user-entered text in memory, opens MainActivity, and hands it to the existing session-creation path. No external-intent confirmation bypass is introduced.

The panel header always provides Open chat and Close outside MainActivity. Open chat pauses active generation before opening the app. Close stops active work and dismisses all overlays. The dismissed state survives service reconnects and resets when the user opens MainActivity or starts another task. Tapping the bubble only minimizes/expands the panel.

Controls have a 420 dp maximum width and fit above system bars and the keyboard. Long detail text scrolls within the remaining height. The bubble moves clear of the panel without replacing its saved position.

## Capture and touch handling

On Android 14+, `WindowScreenshotComposer` uses the public [takeScreenshotOfWindow API](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService#takeScreenshotOfWindow(int,java.util.concurrent.Executor,android.accessibilityservice.AccessibilityService.TakeScreenshotCallback)), which excludes accessibility overlays. It composes app, keyboard, and system-bar surfaces at their exact display positions. The border and controls can remain visible during these captures.

The composer requires stable geometry, exact buffer dimensions, and complete opaque coverage. Overlapping app windows, magnification, system windows covering content, unavailable window captures, and uncovered wallpaper use full-display capture with temporary overlay suppression. A protected window produces no image. Hardware buffers and bitmaps are released on cancellation. This reduces flickering on supported screens but does not eliminate the display fallback.

 Both bubble and controls become untouchable during injected gestures and restore their flags afterward. This lets an agent act at a position occupied by the bubble without toggling its UI.

Expanded accessibility controls may use the existing full-screen interaction shield during automation. The bubble is placed above that window. Minimized controls have no full-screen touch shield. Takeover releases interaction locking while keeping controls available.

**Touch protection** is off by default, retaining the saved compact-overlay preference. Enabling it adds the existing full-screen touch shield while active controls are expanded. This remains optional because the OPPO Find X8 previously revoked accessibility after full-screen overlays.

**Action indicators** is independent and enabled by default. Four 2 dp edge windows draw the border. A 64 dp moving window draws tap, long-press, and swipe feedback. These windows do not intercept input. Disable this setting if an OEM still rejects the overlays. Emulator verification does not establish OPPO compatibility.

## MainActivity and virtual display

`ServiceOverlayController` treats MainActivity's `onResume` and `onStop` as authoritative. It ignores stale non-self accessibility-window events while MainActivity is resumed. Its hidden callback changes location to another app only when the location was still MainActivity, preserving a concurrently opened virtual-display viewer.

Virtual-display navigation remains available in the expanded controls. Bubble taps only toggle controls and never open a viewer implicitly. The viewer still finishes when its state is Hidden with no active task. Completed and error states retain their controls instead of becoming Hidden automatically.

## Other overlays

- `CapsuleOverlayHost`: focusable text input when idle, done, answering a question, or taking over. Binds shared drafts and owns transient confirmation UI.
- `GlowOverlayHost`: task activity feedback, controlled by Action indicators and removed after completion.
- `VisualizerOverlayHost`: tap, long-press, and swipe feedback in complete display coordinates. Hidden when the user is not watching the controlled screen.
- `ServiceLifecycleOwner`: lifecycle and saved-state ownership for service Compose views.

Voice permission requests still use MainActivity's dedicated permission flow. See [voice input](capsule/voice.md). Gesture coordinates and screenshot suppression are described in [phone actions](../infra/tool/phone_actions.md) and [perception](../infra/perception.md).
