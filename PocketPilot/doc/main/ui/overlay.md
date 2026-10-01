# Overlay system

PocketPilot uses accessibility overlay windows outside MainActivity. The main chat embeds its own controls and hides the floating windows. `OverlayComposeHost` owns the Compose controls and bubble. `EffectWindow` owns the small non-interactive indicator windows.

## Persistent bubble

`BubbleOverlayHost` and `OverlayBubbleCompose` replace the static status island. The bubble is available over other apps in accessibility and virtual-display modes, including when the agent is idle. Tapping it replaces the bubble with the task panel. The panel’s X minimizes it back to the bubble.

Drag uses absolute screen touch positions and Android's touch-slop threshold to distinguish moving from tapping. Release docks the bubble to the nearest side. The selected side and relative vertical position are saved locally. System-bar and cutout insets bound its position, and configuration changes reposition it within the new display geometry.

Dragging reveals a dismiss target at the bottom center. Dropping the bubble there stops active work and dismisses every overlay. Repositioning pauses active work during the drag and resumes only the pause that drag requested. Manual takeover, Stop, dismissal, locking, or opening MainActivity cancels that automatic resume. Plain taps open the controls.

Tasks started from the main chat use the bubble; submitting through an open panel keeps the panel open. Completion and session expiry preserve the user’s expanded/minimized choice. Questions, approvals, and errors open the controls for attention, after which the user may minimize them. The bubble uses the app’s primary color; task status stays in the panel. The edge glow is limited to active tasks.

Completed results remain in `CapsuleStateHolder` without an automatic hide timer, including after idle session expiry. Expanded controls show the result as scrollable Markdown, navigation, and a composer. Stopping a session retains a stopped result. The main chat returns directly to its idle composer after completion.

The service state holder owns shared task/note and question-answer drafts. They survive minimizing and switching to chat. A new question clears only its answer draft. Sending a task from the overlay reuses a compatible session or creates one in the service without opening MainActivity. It submits `Op.UserInput(observeScreen = true)`, so the first model request includes the app already on screen. Startup failure or cancellation restores the draft.

The panel header provides compact New chat, Open chat, and Minimize icon buttons outside MainActivity. Open chat pauses active generation before opening the app. New chat starts an empty conversation on the current screen and archives the previous chat. Minimize preserves the task and draft. Only dropping the bubble on the dismiss target stops and removes everything. Dismissal survives service reconnects and late task events until the user opens MainActivity.

`DeviceScreenState` hides all controls and indicators immediately when the screen turns off or locks. Running work requests takeover, and pending overlay startup is canceled. Unlocking restores eligible overlays but never resumes paused work automatically.

Controls have a 420 dp maximum width and fit above system bars and the keyboard. Details and task buttons scroll within the remaining height, preserving the header and composer above a landscape keyboard. The bubble returns to its saved position when the panel is minimized.

## Capture and touch handling

On Android 14+, `WindowScreenshotComposer` uses the public [takeScreenshotOfWindow API](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService#takeScreenshotOfWindow(int,java.util.concurrent.Executor,android.accessibilityservice.AccessibilityService.TakeScreenshotCallback)), which excludes accessibility overlays. It composes app, keyboard, and system-bar surfaces at their exact display positions. The border and controls can remain visible during these captures.

The composer requires stable geometry, exact buffer dimensions, and complete opaque coverage. Overlapping app windows, magnification, system windows covering content, unavailable window captures, and uncovered wallpaper use full-display capture with temporary overlay suppression. A protected window produces no image. Hardware buffers and bitmaps are released on cancellation. This reduces flickering on supported screens but does not eliminate the display fallback.

The bubble remains touchable during injected gestures. A stroke that overlaps it moves the unheld bubble to a nearby clear position before dispatch, then restores its preferred position with the docking animation. Holding the bubble delays injection. Dragging requests takeover, and both the execution delay and gesture setup delay check interruption before acting. Android interruption of a running stroke is reported as a recoverable action failure, rather than ending the task.

Compact controls remain interactive for strokes outside their actual window bounds. Intersecting strokes temporarily suppress both panel rendering and touch interception. Gesture and screenshot suppression compose across nested leases and recreated windows. If no clear bubble position exists, the action fails without disabling the bubble.

Expanded accessibility controls may use the full-screen interaction shield during automation. Every injected gesture temporarily passes through that shield and hides its panel, with the bubble hidden while the panel is expanded. Minimized controls have no full-screen touch shield. Takeover releases interaction locking while keeping controls available.

**Touch protection** is off by default, retaining the saved compact-overlay preference. Enabling it adds the existing full-screen touch shield while active controls are expanded. This remains optional because the OPPO Find X8 previously revoked accessibility after full-screen overlays.

**Action indicators** is independent and enabled by default. Four 2 dp edge windows draw the border. A 64 dp moving window draws tap, long-press, and swipe feedback. These windows do not intercept input. Disable this setting if an OEM still rejects the overlays. Emulator verification does not establish OPPO compatibility.

## Removing the app from Recents

Removing PocketPilot's task dismisses all overlay windows immediately and ends the current session. Dismissal remains set through accessibility reconnection until the app is opened again. Home and ordinary app switching retain the overlay. Accessibility permission remains enabled.

The connected accessibility service registers a started state so Android delivers `onTaskRemoved`; binding alone does not receive that callback. MainActivity renews tracking when reopened. The service uses `START_NOT_STICKY` and releases its started state on task removal or accessibility unbind, allowing normal accessibility cleanup. See [Android's task-removal dispatch](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android15-release/services/core/java/com/android/server/am/ActiveServices.java).

## MainActivity and virtual display

`ServiceOverlayController` treats MainActivity's `onResume` and `onStop` as authoritative. It ignores stale non-self accessibility-window events while MainActivity is resumed. Its hidden callback changes location to another app only when the location was still MainActivity, preserving a concurrently opened virtual-display viewer.

Virtual-display navigation remains available in the expanded controls. Bubble taps only toggle controls and never open a viewer implicitly. The viewer still finishes when its state is Hidden with no active task. Completed and error states retain their controls instead of becoming Hidden automatically.

## Other overlays

- `CapsuleOverlayHost`: focusable text input when idle, done, answering a question, or taking over. Binds shared drafts and owns transient confirmation UI.
- `GlowOverlayHost`: task activity feedback, controlled by Action indicators and removed after completion.
- `VisualizerOverlayHost`: tap, long-press, and swipe feedback in complete display coordinates. Hidden when the user is not watching the controlled screen.
- `ServiceLifecycleOwner`: lifecycle and saved-state ownership for service Compose views.

Voice permission requests still use MainActivity's dedicated permission flow. See [voice input](capsule/voice.md). Gesture coordinates and screenshot suppression are described in [phone actions](../infra/tool/phone_actions.md) and [perception](../infra/perception.md).
