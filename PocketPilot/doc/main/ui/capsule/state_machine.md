# Capsule state and overlay visibility

The task-state transitions are documented in [the capsule state machine](../../state_machines/ui_capsule.md). `CapsuleStateHolder` owns task mode, context, platform mode, turn phase, and stop feedback. `ServiceOverlayController` separately owns whether the controls are expanded.

`ShowPreference` is `BUBBLE` or `CAPSULE`. The bubble and panel are mutually exclusive. Tapping the bubble opens the panel; the panel’s X returns to the bubble. Tasks submitted from the panel keep it open. Terminal events preserve the user’s selection. User questions, approvals, and session errors initially expand the controls, but the user can minimize them again.

Done retains its full result without a timer. Session expiry preserves Done and Error. Ending an active session records Stopped. The panel’s X preserves work. The bubble’s drag-to-dismiss target stops active work and persists a separate dismissed flag. Every overlay is hidden without clearing the last result. Opening MainActivity clears dismissal; delayed task events do not. Starting another task replaces the previous result. Clearing chat history, or deleting the chat retained by the overlay, resets the holder to Hidden and clears its result and both drafts. Clear traces preserves them.

Data deletion temporarily hides all floating controls and blocks Main input until the operation finishes. MainActivity hides floating windows because it has embedded controls. Virtual-display attention states can still show controls over MainActivity. The edge glow requires an active task. Expanded active controls may use the interaction shield; Done, Error, Hidden, and Takeover release it.

BubbleOverlayHost saves the selected side and height fraction, clamps movement to usable screen bounds, and handles display configuration changes. Dragging running work requests takeover. Repositioning resumes only that drag's pause; interruption by lock, dismissal, Stop, or manual takeover revokes automatic resume. Screen-off and lock hide all overlays, and unlocking never resumes work automatically.

The bubble stays touchable during gestures and temporarily moves clear of overlapping strokes. Compact controls pass through only intersecting strokes; full-screen touch protection passes through every injected stroke. Panels needing pass-through are hidden until their leases close. Screenshot fallback independently suppresses all overlays. See [capture and touch handling](../overlay.md#capture-and-touch-handling).

New chat clears the result, response text, latest tool, and both drafts in the shared holder. Old-session events still finish recording, but cannot update the current UI. The main chat consumes the same reset and removes its old session and reload references.
