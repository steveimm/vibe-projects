# Architecture

PocketPilot is a Kotlin/Jetpack Compose Android automation app using a user-configured Chat Completions server.

- [Agent runtime](agent/overview.md): the single-agent task loop.
- [Execution](agent/loop.md): perception, model requests, actions, and results.
- [Model context](agent/context.md): conversation history, native reasoning, and compaction.
- [Prompt assembly](agent/turn_prompt_anatomy.md): what is sent to the model.
- [Tools](infra/tools.md): the phone controls and execution policy.
- [Sessions](infra/session.md): ownership, lifecycle, and checkpoints.
- [Model server](infra/llm.md): endpoint configuration and transport.
- [Settings](app/settings.md): user controls and app access.
- [Termux](app/termux_shell.md): optional workspace commands.
- [History](app/history/runtime.md): recording and restoration.
- [Protocol](protocol/overview.md): configuration, operations, and events.
- [State machines](state_machines/README.md): lifecycle details.
- [UI](ui/tech_design.md): chat and floating controls.
- [Evaluation](eval/eval.md): task runners and artifacts.

Source packages are under `app/src/main/kotlin/id/steveimm/pocketpilot/`. The main boundaries are `app/`, `session/`, `agent/`, `llm/`, `tool/`, `platform/`, `history/`, and `ui/`.
