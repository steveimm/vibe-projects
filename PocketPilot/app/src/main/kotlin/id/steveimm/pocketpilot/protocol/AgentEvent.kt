package id.steveimm.pocketpilot.protocol

/** AgentEvent - Events emitted by the agent session to the UI layer. */
sealed interface AgentEvent {
    /** Session this event belongs to */
    val sessionId: SessionId

    /** When this event occurred */
    val timestamp: Long
}
