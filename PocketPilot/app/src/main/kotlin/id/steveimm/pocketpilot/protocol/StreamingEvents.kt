package id.steveimm.pocketpilot.protocol

/** A text delta from the streaming response. */
data class MessageDelta(
        override val sessionId: SessionId,
        override val timestamp: Long,
        val turnId: String,
        val delta: String
) : StreamingDomainEvent

/** Reasoning supplied by the model server, kept separate from assistant answers and tool arguments. */
data class ReasoningDelta(
    override val sessionId: SessionId,
    override val timestamp: Long,
    val turnId: String,
    val delta: String,
) : StreamingDomainEvent
