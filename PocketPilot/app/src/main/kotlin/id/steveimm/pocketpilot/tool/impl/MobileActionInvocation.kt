package id.steveimm.pocketpilot.tool.impl

import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.platform.AndroidPlatform
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.ToolExecutionContext
import id.steveimm.pocketpilot.tool.ToolExecutionResult
import id.steveimm.pocketpilot.tool.ToolInvocation
import id.steveimm.pocketpilot.tool.action.ActionOutcome
import org.json.JSONObject

/** Thin glue: routes to executor, maps ActionOutcome to ToolExecutionResult. */
class MobileActionInvocation(
    override val params: JSONObject,
    private val description: String,
    private val executeAction: suspend (AndroidPlatform, ScreenSnapshot?, () -> Boolean, AppClassifier?) -> ActionOutcome
) : ToolInvocation {
    override val toolName = "mobile_action"

    override fun getDescription(): String = description

    override suspend fun execute(context: ToolExecutionContext): ToolExecutionResult {
        if (context.isCancelled()) return ToolExecutionResult.Cancelled()
        val outcome = executeAction(context.platform, context.currentSnapshot, context::isCancelled, context.appClassifier)
        return mapOutcome(outcome)
    }

    private fun mapOutcome(outcome: ActionOutcome): ToolExecutionResult = when (outcome) {
        is ActionOutcome.Success -> {
            val output = buildString {
                append(outcome.message)
                if (!outcome.verified) append(" [unverified]")
                if (outcome.attemptTrail.size > 1) {
                    append("\nAttempts: ${outcome.attemptTrail.joinToString(" -> ")}")
                }
            }
            ToolExecutionResult.Success(output = output, observation = outcome.observation)
        }
        is ActionOutcome.Failed -> {
            val output = buildString {
                append(outcome.reason)
                if (outcome.attemptTrail.size > 1) {
                    append("\nAttempts: ${outcome.attemptTrail.joinToString("; ")}")
                }
            }
            ToolExecutionResult.Failure(output)
        }
        is ActionOutcome.Cancelled -> ToolExecutionResult.Cancelled(outcome.reason)
    }
}
