package id.steveimm.pocketpilot.platform

/** ActionResult — result of executing an atomic UIAction. */
sealed interface ActionResult {

    /** Action executed successfully. */
    data class Success(val message: String = "Action completed") : ActionResult

    /** Action failed to execute. */
    data class Failure(val reason: String) : ActionResult

    /** Action was cancelled before completion. */
    data class Cancelled(val reason: String = "Action cancelled") : ActionResult
}
