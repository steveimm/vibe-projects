# Capsule user flows

## Outside PocketPilot

The floating bubble stays available over other apps. Tap it to expand the task controls, and tap it again to collapse them. Drag it to reposition it; release docks it to the nearest side. Its position survives toggling, task completion, and service restarts.

During a task, the expanded controls retain Takeover, Resume, Stop, notes, questions, and approval actions. A question or approval initially expands the controls. Minimizing does not answer or dismiss a pending request.

After completion, the bubble remains and the red activity glow stops. Expanding shows the last result as scrollable Markdown, a new-request composer, and app navigation. Draft text survives minimization. New requests use the current session when possible. If it has ended, MainActivity opens and creates or reloads a session using the existing path.

Stopping leaves a stopped result in the bubble. Session idle expiry does not clear the last result. Close dismisses the bubble and panel. If work is active, Close also stops it. Dismissal survives service reconnects until MainActivity opens or another task begins. Errors retain their explanation and accept a new request.

## Main app

Floating controls are hidden while MainActivity is resumed. Completed answers remain in the chat, and the embedded composer is immediately ready for another request. Returning to another app restores the bubble.

## Virtual display

The bubble toggles task controls without implicitly opening the viewer. Every expanded panel provides Open chat and Close. Open viewer is available where applicable. Open chat pauses running work first. Viewer lifecycle and idle-finish rules remain in ServiceOverlayController.

## Screenshot and gesture interaction

Supported Android 14+ window captures exclude accessibility overlays without hiding them. Complex or unsupported compositions use the display fallback with temporary suppression. During injected gestures, both bubble and controls become untouchable, allowing actions at their screen positions to reach the underlying app. See [overlay system](../overlay.md) for ownership and lifecycle details.
