package id.steveimm.pocketpilot.protocol

/** A new task has started within the session. */
data class TaskStarted(
        override val sessionId: SessionId,
        override val timestamp: Long,
        val taskId: String,
        val input: String
) : TaskLifecycleEvent

/** A task has completed. */
data class TaskCompleted(
        override val sessionId: SessionId,
        override val timestamp: Long,
        val taskId: String,
        val result: String?,
        val outcome: TaskOutcome,
        val handoff: CompletionHandoff? = null,
) : TaskLifecycleEvent
