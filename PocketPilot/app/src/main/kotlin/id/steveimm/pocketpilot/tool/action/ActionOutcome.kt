package id.steveimm.pocketpilot.tool.action

import id.steveimm.pocketpilot.tool.ToolObservation

/** Result of executor-level action execution. */
sealed interface ActionOutcome {
    data class Success(
        val message: String,
        val observation: ToolObservation?,
        val attemptTrail: List<String>,
        val verified: Boolean = true
    ) : ActionOutcome

    data class Failed(
        val reason: String,
        val attemptTrail: List<String>
    ) : ActionOutcome

    data class Cancelled(
        val reason: String
    ) : ActionOutcome
}
