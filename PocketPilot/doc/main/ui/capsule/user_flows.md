# Capsule user flows

## Outside PocketPilot

The floating bubble stays available over other apps. Tap it to expand the task controls, and tap it again to collapse them. Drag it to reposition it; release docks it to the nearest side. Dropping it on the bottom-center dismiss target stops active work and removes the overlays. Its preferred position survives toggling, task completion, and service restarts.

During a task, the expanded controls retain Takeover, Resume, Stop, notes, questions, and approval actions. A question or approval initially expands the controls. Minimizing does not answer or dismiss a pending request.

After completion, the bubble remains and the red activity glow stops. Expanding shows the last result as scrollable Markdown, a new-request composer, and app navigation. Draft text survives minimization. New requests reuse a compatible session or create one in the service without opening MainActivity. Their first model request includes the current app's screen, so the user can navigate to an app before asking for work.

Stopping leaves a stopped result in the bubble. Session idle expiry does not clear the last result. Close uses the same stop-and-dismiss path as the drag target. Dismissal survives service reconnects and late task events until MainActivity opens. Errors retain their explanation and accept a new request.

Screen-off or lock immediately hides all overlays and pauses running work. Unlocking does not resume it. Repositioning a bubble can resume the pause that drag requested, but cannot resume a manual takeover or a task paused by locking the phone.

## Main app

Floating controls are hidden while MainActivity is resumed. Completed answers remain in the chat, and the embedded composer is immediately ready for another request. Returning to another app restores the bubble.

## Virtual display

The bubble toggles task controls without implicitly opening the viewer. Every expanded panel provides Open chat and Close. Open viewer is available where applicable. Open chat pauses running work first. Viewer lifecycle and idle-finish rules remain in ServiceOverlayController.

## Screenshot and gesture interaction

Supported Android 14+ window captures exclude accessibility overlays without hiding them. Complex or unsupported compositions use the display fallback with temporary suppression. During gestures, the bubble stays touchable and moves clear of overlapping strokes. A held bubble delays dispatch; dragging requests takeover. Compact panels stay interactive unless the stroke crosses them. Panels needing pass-through are hidden for that lease. The optional full-screen shield still passes through every injected gesture. See [overlay system](../overlay.md) for ownership and lifecycle details.
