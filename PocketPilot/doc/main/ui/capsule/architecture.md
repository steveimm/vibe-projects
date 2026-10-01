# Capsule architecture

`CapsuleStateHolder` owns mode, context, platform mode, turn phase, assistant response text, latest tool call, Stop feedback, and shared drafts. `ServiceOverlayController` owns panel visibility, persisted dismissal, and returning to MainActivity. See [overlay behavior](../overlay.md) for window ownership and capture details, and [state transitions](../../state_machines/ui_capsule.md) for mode guards.

`SmartCapsuleSurface` renders both the embedded chat controls and the floating panel. It derives `CapsuleRenderSpec` and `NavSpec`, then renders a header, optional scrollable detail, action buttons, and input. Navigation stays in the header even for questions, approvals, and errors. The bubble opens the panel and hides while it is expanded. The panel’s X minimizes without stopping the task; dragging the bubble to the dismiss target stops and removes the floating controls.

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

The service keeps task/note text separate from question-answer text. Main binds its composer to the same draft as the overlay. A new question call clears only the answer draft. Recomposition, minimizing, and switching surfaces do not clear it. Successful submission clears the submitted draft. Explicit history deletion also clears the affected conversation's drafts and retained result; [deletion ownership](../../app/history/persistence.md#deletion-ownership) describes the shutdown and write ordering.

Hidden, Done, and Error submit new input. Questions submit a response tied to the current call ID. Takeover submits a note and resumes. Running input submits a note where editing is allowed. Opening the drawer or Settings disables chat input and cancels dictation without clearing text. Incoming questions cannot open the keyboard behind those surfaces, and closing them does not repeat question autofocus. Voice uses the same draft and submission path, with permission handling described in [voice input](voice.md).

New overlay tasks are created by the service without opening MainActivity. They capture the current app before the first model request. Main-chat tasks retain the normal conversation-first behavior.

## Runtime controls

Takeover cancels active model transport, waits for execution to reach its pause boundary, and prevents queued model actions from executing. Resume performs a fresh observation. Open chat requests this handover before launching MainActivity. Stop cancels work from both Running and Paused states. The panel’s X minimizes without stopping. Dragging the bubble onto its dismiss target stops and removes the windows.

Dragging the bubble owns a temporary takeover and resumes only that pause after repositioning. Dismissal, lock, Stop, manual takeover, and opening MainActivity revoke that ownership. Screen-off and lock hide every overlay immediately; unlocking does not resume work. [Overlay behavior](../overlay.md) defines gesture priority, touch protection, and screenshot exclusion.

Progress uses `MessageDelta` content, with Thinking as the fallback before response text arrives. `ActionProposed` supplies a separate latest-tool line. Phase changes do not replace the response text. Native reasoning stays in the expandable chat activity panel, and the final answer remains outside that panel. An interrupted stream cannot become a completed answer.

New chat in either surface calls the service-owned conversation reset. The old session finishes recording without updating the new UI. Main clears reload targets and queued input, and future input waits for reset completion. Reset notifications preserve drafts typed afterward when switching between surfaces.
