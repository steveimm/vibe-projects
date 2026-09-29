# Agent loop

PocketPilot runs one agent. Each new user message is sent unchanged with conversation history. The model can respond directly or select a tool. The runtime captures the phone after a screen-reading or phone-action request, then includes that fresh observation in the next model turn. Non-phone tools can return text without triggering a screenshot.

## Response contract

- Structured tool calls continue the loop. Their results return with matching call IDs.
- Nonblank assistant content with `finish_reason=stop` and no tool calls ends the task.
- Native reasoning is streamed separately, displayed in the chat, and preserved under the server's original reasoning field in later requests.
- Reasoning-only, empty, truncated, filtered, and unterminated responses cannot finish a task.
- Plain text is never parsed into executable tool calls.
- A finished response is not a verified success verdict. The answer explains what was done or what blocked progress.

## Ownership

| Component | Responsibility |
| --- | --- |
| `Agent` | Pause, cancellation, retries, compaction, task loop |
| `AgentTurnRunner` | Conditional capture, app-access masking, planning and execution |
| `TurnPlanningPhaseRunner` | Prompt/history, streamed events, native reasoning |
| `Turn` | Response parsing and terminal-response validation |
| `TurnExecutionPhaseRunner` | Tool routing, results, post-action observations |
| `PromptBuilder` | Conversation history and current screen observation |
| `AgentTrace` | Requests, responses, screenshots, tool outcomes and summary |

App-access policy is enforced by `ToolRouter` and `PolicyEngine`. Screens from blocked apps are masked before model input. The optional Termux bridge is advertised only when available.

See [runtime state machine](../state_machines/agent_run_loop.md) and [tool roster](../infra/tools.md).
