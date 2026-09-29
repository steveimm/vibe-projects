# Model request assembly

`SessionAgentRunner` starts with `DefaultAgentDefinition.systemPrompt`, substitutes the current date, and adds workspace-command guidance only when Termux is available.

`TurnPlanningPhaseRunner` captures one current observation and invokes `PromptBuilder`. The request contains:

1. The system prompt.
2. Retained conversation history, including native assistant reasoning and tool call/result pairs.
3. A current screenshot observation and factual warnings only after a screen-reading or phone-action request.
4. The currently available tool schemas in the Chat Completions `tools` field.

There are no injected app skills, separate todo lists, scratchpad keys, or persistent-memory recalls. The model's exposed reasoning stays in its original assistant-message field rather than being inserted as user text.

`ChatCompletionInterop` combines consecutive assistant calls into the Chat Completions representation and preserves reasoning metadata. `ChatCompletionClient` sends requests to the explicitly configured server. Streaming reasoning and visible assistant content use separate event paths.

Native reasoning is inspectable in the expanded chat trace. The floating controls show runtime phase status. Tool schemas do not request step headings or explanations.

When context is compacted, the request is rebuilt from the updated history and the same current observation. See [context](context.md).

The first turn of each user message uses conversation history alone. `read_screen` requests a current observation, optionally after a delay. `open_app` can run without an initial screenshot. Phone actions receive fresh observations afterward. Normal replies and text-only tool interactions do not automatically capture the phone.
