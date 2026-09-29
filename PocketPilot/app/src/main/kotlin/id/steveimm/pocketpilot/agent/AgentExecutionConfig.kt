package id.steveimm.pocketpilot.agent

import id.steveimm.pocketpilot.protocol.SessionId

/** Configuration for the session's single agent. */
data class AgentExecutionConfig(
    val goal: String,
    val sessionId: SessionId,
    val taskId: String = sessionId.value,
    val uiSettleDelayMs: Long = 3000,
    val debugMode: Boolean = false,
    val systemPrompt: String? = null,
    val allowedToolNames: Set<String>? = null,
    val modelName: String = "",
    val evalTurnBudget: Int? = null,
)
