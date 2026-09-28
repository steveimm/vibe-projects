package id.steveimm.pocketpilot.protocol

/** Op - Operations sent from the UI layer to the agent session. */
sealed interface Op {

    /** User takes control of the device. */
    data object Takeover : Op

    /** Resume from takeover (user returns control to agent). */
    data object Resume : Op

    /** Interrupt the current turn. */
    data object Interrupt : Op

    /** Shutdown the session gracefully. */
    data object Shutdown : Op

    /** User provides input to the agent. */
    data class UserInput(
        val text: String
    ) : Op

    /** User injects a mid-task message into the agent's conversation history. */
    data class Supplement(
        val text: String
    ) : Op

    /** User responds to an ask_user request (question answer or action completion). */
    data class UserResponse(
        val callId: String,
        val response: String
    ) : Op

    /** User responds to an approval request. */
    data class Approve(
        /** ID of the action being approved/denied */
        val actionId: String,

        /** User's decision */
        val decision: ApprovalDecision,

        /** Lifetime of the app-level allow decision. Ignored for rejections. */
        val scope: ApprovalScope = ApprovalScope.SESSION,

        /** Package name that owns the app-level approval. */
        val packageName: String
    ) : Op
}
