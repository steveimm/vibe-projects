package id.steveimm.pocketpilot.agent.cognition.policy

import id.steveimm.pocketpilot.agent.ToolCallRequest
import id.steveimm.pocketpilot.agent.TurnResult
import id.steveimm.pocketpilot.tool.ToolName

private val COMPLETE_TASK_TOOL = ToolName.CompleteTask.raw
/** Result of choosing which tool calls from one LLM turn should actually execute. */
internal data class ToolArbitrationResult(
        val selectedToolCalls: List<ToolCallRequest>,
        val hasCompletionTool: Boolean,
        val hasScreenAction: Boolean,
        val droppedToolCalls: List<ToolCallRequest>
)

/** Result of deciding whether the current turn should end the whole task. */
internal data class CompletionDecision(
        val shouldComplete: Boolean,
        val summary: String?,
        val success: Boolean
)

/** Turn-level policy for two questions: 1) If the model returned multiple tool calls, which one do we execute? 2) Should this turn be
 * treated as task completion? */
internal class TurnToolPolicy {
    /** Arbitration rule: - Hoist only cognitive tools. - Keep other selected tools in model order. - Keep `complete_task` only when no
     * screen-changing tool is selected. */
    fun arbitrateToolCalls(
        toolCalls: List<ToolCallRequest>
    ): ToolArbitrationResult {
        if (toolCalls.isEmpty()) {
            return ToolArbitrationResult(
                selectedToolCalls = emptyList(),
                hasCompletionTool = false,
                hasScreenAction = false,
                droppedToolCalls = emptyList()
            )
        }

        val completionCall = toolCalls.find { it.name == COMPLETE_TASK_TOOL }
        val hasCompletionTool = completionCall != null
        val nonCompletionCalls = toolCalls.filter { it.name != COMPLETE_TASK_TOOL }
        val screenCalls =
                nonCompletionCalls.filter { call ->
                        ToolName.from(call.name).isScreenChanging
                }
        val hasScreenAction = screenCalls.isNotEmpty()
        val selectedCompletion = if (!hasScreenAction) completionCall else null
        val selectedToolCalls =
                buildList {
                        addAll(nonCompletionCalls)
                        selectedCompletion?.let(::add)
                }

        val selectedToolIds = selectedToolCalls.map { it.id }.toSet()
        val droppedToolCalls = toolCalls.filterNot { it.id in selectedToolIds }

        return ToolArbitrationResult(
                selectedToolCalls = selectedToolCalls,
                hasCompletionTool = hasCompletionTool,
                hasScreenAction = hasScreenAction,
                droppedToolCalls = droppedToolCalls
        )
    }

    /** Completion rule: - Only complete when model says complete AND no screen action is selected this turn. */
    fun decideCompletion(
            turnResult: TurnResult,
            arbitration: ToolArbitrationResult
    ): CompletionDecision {
        val shouldComplete = turnResult.isComplete && !arbitration.hasScreenAction
        if (!shouldComplete) {
            return CompletionDecision(shouldComplete = false, summary = null, success = false)
        }
        val completeTaskCall = turnResult.toolCalls.find { it.name == COMPLETE_TASK_TOOL }
        val status = completeTaskCall?.arguments?.optString("status", "success")?.trim()?.lowercase()
        val success = status != "failure"
        val summary =
                completeTaskCall?.arguments?.optString("answer")?.takeIf { it.isNotBlank() }
                        ?: completeTaskCall?.arguments?.optString("summary") ?: turnResult.content
                                ?: "Goal achieved"
        return CompletionDecision(shouldComplete = true, summary = summary, success = success)
    }
}
