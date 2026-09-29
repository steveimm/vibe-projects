# Sessions

`AgentSession` serializes lifecycle operations through its actor. A session owns conversation history, model clients, platform access, tool routing, approval policy, user-response handling, recording, and tracing. There is one agent per running task.

`SessionServices.create()` resolves the configured server/model, snapshots Termux availability, registers the allowed tools, and creates history/recording services. No browser runtime, skill manager, planning state, or persistent-memory service is created.

`SessionAgentRunner` builds the agent configuration and runs `Agent`. It relays completion through the session's serialized lifecycle path. User input, pause, resume, stop, and approvals stay owned by the session.

`SessionCheckpointCoordinator` persists configuration and conversation history, including native reasoning. Idle-ready and closed checkpoints may be restored. Running-dirty checkpoints are not safe resume points. A checkpoint is flushed before an idle session can be released.

Shutdown cancels tools and pending user responses, stops the platform, closes current and superseded model clients, and closes tracing last. Cleanup aggregates failures so one failing resource does not prevent the remaining cleanup.

See [history runtime](../app/history/runtime.md), [model server](llm.md), and [tools](tools.md).
