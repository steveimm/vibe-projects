# Capsule architecture

`CapsuleStateHolder` owns mode, context, platform mode, turn phase, Stop feedback, and shared drafts. `ServiceOverlayController` owns panel visibility, persisted dismissal, and returning to MainActivity. See [overlay behavior](../overlay.md) for window ownership and capture details, and [state transitions](../../state_machines/ui_capsule.md) for mode guards.

`SmartCapsuleSurface` renders both the embedded chat controls and the floating panel. It derives `CapsuleRenderSpec` and `NavSpec`, then renders a header, optional scrollable detail, action buttons, and input. Navigation stays in the header even for questions, approvals, and errors. The bubble supplies minimize/expand. Close dismisses the entire overlay.

`CapsuleControlBar` renders Takeover, Resume, Done, approval choices, and Stop. `CapsuleInputBar` binds the supplied mutable draft. `CapsuleBinding` connects chat to service flows and guarded response callbacks without owning another task state.

## Rendering

| Mode | Status/detail | Task controls | Input |
|---|---|---|---|
| Hidden | Empty | None | New task |
| Running | Reading screen, Thinking, or Acting | Takeover, Stop | Note, after takeover outside Main |
| TakeoverPending | Handing over | Disabled handover, Stop | Disabled outside Main |
| Takeover | Paused | Resume, Stop | Note and resume |
| WaitingForInput | Awaiting response, question | Stop | Answer |
| WaitingForAction | Action needed, instruction | Done, Stop | None |
| WaitingForApproval | App access, app permission question | Always, Session, Reject | None |
| Done | Finished or Stopped, optional result | None | New task |
| Error | Error, explanation | None | New task |

Outside Main, every row also has Open chat and Close. Virtual-display contexts expose Open viewer when useful. Main renders completed/error results in the chat and returns to an idle composer.

## Drafts and input

The service keeps task/note text separate from question-answer text. Main binds its composer to the same draft as the overlay. A new question call clears only the answer draft. Recomposition, minimizing, and switching surfaces do not clear it. Successful submission clears the submitted draft.

Hidden, Done, and Error submit new input. Questions submit a response tied to the current call ID. Takeover submits a note and resumes. Running input submits a note where editing is allowed. Voice uses the same draft and submission path, with permission handling described in [voice input](voice.md).

## Runtime controls

Takeover cancels active model transport, waits for execution to reach its pause boundary, and prevents queued model actions from executing. Resume performs a fresh observation. Open chat requests this handover before launching MainActivity. Stop cancels work from both Running and Paused states. Close dispatches Stop when necessary and immediately removes the windows.

Phase status comes from `TurnPhaseChanged`. Native reasoning is streamed and retained in chat separately, with no model-generated capsule heading. An interrupted stream cannot become a completed answer.
