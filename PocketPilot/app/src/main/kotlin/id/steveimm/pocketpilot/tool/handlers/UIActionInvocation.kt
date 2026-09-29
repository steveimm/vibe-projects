package id.steveimm.pocketpilot.tool.handlers

import android.util.Log
import id.steveimm.pocketpilot.platform.ActionResult
import id.steveimm.pocketpilot.platform.UIAction
import id.steveimm.pocketpilot.tool.action.buildObservation
import id.steveimm.pocketpilot.tool.ToolExecutionContext
import id.steveimm.pocketpilot.tool.ToolExecutionResult
import id.steveimm.pocketpilot.tool.ToolInvocation
import id.steveimm.pocketpilot.tool.ToolObservation
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import org.json.JSONObject

/** UIActionInvocation — executes a UIAction for phone actions. */
class UIActionInvocation(
    override val toolName: String,
    override val params: JSONObject,
    private val description: String,
    private val uiAction: UIAction,
    private val requiresScreenshot: Boolean = false,
) : ToolInvocation {

    companion object {
        private const val TAG = "UIActionInvocation"
        private const val UI_SETTLE_DELAY_MS = 300L
    }

    override fun getDescription(): String = description

    override suspend fun execute(context: ToolExecutionContext): ToolExecutionResult {
        if (context.isCancelled()) {
            return ToolExecutionResult.Cancelled("Cancelled before execution")
        }

        if (requiresScreenshot && context.currentSnapshot?.image == null) {
            return ToolExecutionResult.Failure("No current screenshot. Use read_screen before entering text.")
        }
        val result = context.platform.performAction(uiAction)

        return when (result) {
            is ActionResult.Success -> {
                val observation = capturePostActionObservation(context)
                ToolExecutionResult.Success(output = result.message, observation = observation)
            }
            is ActionResult.Failure -> ToolExecutionResult.Failure(result.reason)
            is ActionResult.Cancelled -> ToolExecutionResult.Cancelled(result.reason)
        }
    }

    private suspend fun capturePostActionObservation(
        context: ToolExecutionContext
    ): ToolObservation? {
        return try {
            delay(UI_SETTLE_DELAY_MS)
            val snapshot = context.platform.captureScreen()
            buildObservation(snapshot, context.platform, context.appClassifier)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "Failed to capture post-action observation: ${e.message}")
            null
        }
    }
}
