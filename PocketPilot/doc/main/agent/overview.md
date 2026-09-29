# Agent runtime

PocketPilot runs one agent against the configured local model server. A session can contain multiple user tasks. Each task repeats screen capture, a streamed model request, tool execution, and observation.

`SessionAgentRunner` resolves the prompt and available tools from `DefaultAgentDefinition`. `Agent` controls the loop. `AgentTurnRunner` coordinates `TurnPlanningPhaseRunner` and `TurnExecutionPhaseRunner`. `Turn` handles the model's structured output. `ToolRouter` validates calls and applies app-access policy before execution.

The model receives conversation history and the current screen. Its native reasoning is preserved separately from visible answers and tool arguments. The app does not maintain additional planning or skill state.

Events update the chat, recording service, and floating controls. Session shutdown stops active work and releases the platform, clients, response channels, and trace writer.

See [execution](loop.md), [prompt assembly](turn_prompt_anatomy.md), [context](context.md), and [tools](../infra/tools.md).
