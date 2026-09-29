# Conversation context

`HistoryManager` stores user requests, assistant answers and native reasoning, tool calls, tool results, and screen observations. `PromptBuilder` sends retained history followed by the current observation and factual warnings. There are no separate planning, scratchpad, persistent-memory, or skill tools.

Assistant reasoning stays on the original assistant message using the server's reasoning field. Runtime checkpoints preserve it, and token estimates include its length. Tool call IDs are paired with their results before building Chat Completions messages.

Older screen text is shortened. `Compactor` summarizes an older history prefix when the estimated context approaches the configured model window, retaining recent turns. A context-window rejection can trigger one reactive compaction and request rebuild. Native reasoning in retained recent turns remains available to the next request.

Relevant source:

- `history/HistoryManager.kt`
- `history/ResponseItem.kt`
- `history/Compactor.kt`
- `agent/cognition/prompt/PromptBuilder.kt`
- `history/model/SessionRuntimeSnapshot.kt`
