# Capsule state and overlay visibility

The task-state transitions are documented in [the capsule state machine](../../state_machines/ui_capsule.md). `CapsuleStateHolder` owns task mode, context, platform mode, turn phase, and stop feedback. `ServiceOverlayController` separately owns whether the controls are expanded.

`ShowPreference` is `BUBBLE` or `CAPSULE`. A bubble remains visible outside MainActivity in either state. Tapping it toggles controls without navigating elsewhere. New tasks and terminal events select BUBBLE. User questions, approvals, and session errors initially expand the controls, but the user can minimize them again.

Done retains its full result without a timer. Session expiry preserves Done and Error. Ending an active session records Stopped. Error dismissal returns to the idle composer, with the bubble still available. Starting another task replaces the previous result.

MainActivity hides floating windows because it has embedded controls. Virtual-display attention states can still show controls over MainActivity. The edge glow requires an active task. Expanded active controls may use the interaction shield; Done, Error, Hidden, and Takeover release it.

Drag position is independent of task state. BubbleOverlayHost saves the selected side and height fraction, clamps movement to usable screen bounds, and handles display configuration changes. Screenshot suppression and gesture pass-through apply to both bubble and expanded controls.
