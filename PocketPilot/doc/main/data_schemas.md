# Core data schemas

| Schema | Owner | Purpose |
|---|---|---|
| `SessionConfig` | `protocol/SessionConfig.kt` | Model server, execution, perception, and tracing configuration captured for a session. |
| `SessionRuntimeSnapshot` | `history/model/SessionRuntimeSnapshot.kt` | Reloadable configuration and model history, checkpoint state, timestamp, and last task outcome. |
| `ResponseItem` | `history/ResponseItem.kt` | User/assistant messages and paired tool calls/results used to build model requests. |
| `ModelReasoning` | `llm/ModelReasoning.kt` | Native reasoning text and its original server field name. |
| `MessageRecord` | `history/model/MessageRecord.kt` | Recorded chat content, tool actions, native reasoning, and final answers. |
| Trace events | `trace/` | Diagnostic events and references to screen, request, response, and action artifacts. |

Runtime checkpoints preserve native assistant reasoning. Old saved step captions are read as ordinary text in chat history. No planning, scratchpad, persistent-memory, or skill state is stored by the current runtime.
