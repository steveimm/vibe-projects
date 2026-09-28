package id.steveimm.pocketpilot.protocol

/** Agent thought update for Smart Capsule and chat trace. */
data class ThoughtUpdate(
        override val sessionId: SessionId,
        override val timestamp: Long,
        val full: String,
        val compact: String
) : ThoughtDomainEvent
