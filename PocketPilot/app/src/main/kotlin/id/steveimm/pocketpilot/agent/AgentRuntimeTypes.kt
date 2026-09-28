package id.steveimm.pocketpilot.agent

import id.steveimm.pocketpilot.agent.cognition.context.NavigationState
import id.steveimm.pocketpilot.agent.cognition.policy.ToolArbitrationResult
import id.steveimm.pocketpilot.agent.cognition.policy.TurnToolPolicy
import id.steveimm.pocketpilot.tool.ToolCallResult
import id.steveimm.pocketpilot.tool.ToolName

/** Reason why the agent stopped. */
sealed class AgentStopReason {
    data class GoalAchieved(val message: String = "Goal achieved") : AgentStopReason()
    data object UserRequested : AgentStopReason()
    data class TaskImpossible(val message: String) : AgentStopReason()
    data class Error(val message: String) : AgentStopReason()
}

/** Outcome of a single turn. */
sealed class TurnOutcome {
    data object Continue : TurnOutcome()
    data class Complete(val message: String, val success: Boolean = true) : TurnOutcome()
    data class Error(val message: String, val recoverable: Boolean) : TurnOutcome()
    data object Cancelled : TurnOutcome()
}

/** Mutable runtime state carried across turns. */
internal data class TurnRunnerState(
    val navigationState: NavigationState = NavigationState()
)

/** Full output of one `AgentTurnRunner.executeTurn()` call: - `outcome`: control decision for the outer Agent loop - `nextState`: state
 * to feed into the next turn */
internal data class TurnExecutionResult(
    val outcome: TurnOutcome,
    val nextState: TurnRunnerState
)

/** Outcome of executing the selected tool calls for a turn. */
internal data class ExecutionPhaseResult(
    val executedToolIds: Set<String>,
    val terminatedEarly: Boolean,
    val lastTerminalResult: ToolCallResult?
) {
    companion object {
        val EMPTY = ExecutionPhaseResult(
            executedToolIds = emptySet(),
            terminatedEarly = false,
            lastTerminalResult = null
        )
    }
}

/** Maps the planning + execution results to the control-loop outcome. */
internal fun decideTurnOutcome(
    policy: TurnToolPolicy,
    turnResult: TurnResult,
    arbitration: ToolArbitrationResult,
    execution: ExecutionPhaseResult
): TurnOutcome {
    if (execution.terminatedEarly) {
        return when (val last = execution.lastTerminalResult) {
            is ToolCallResult.Cancelled -> TurnOutcome.Cancelled
            is ToolCallResult.Error -> TurnOutcome.Error(
                message = last.error,
                recoverable = true
            )
            else -> TurnOutcome.Error(
                message = "Tool execution aborted before completion",
                recoverable = true
            )
        }
    }
    val completeTaskCall = arbitration.selectedToolCalls.find { it.name == ToolName.CompleteTask.raw }
    if (completeTaskCall != null && completeTaskCall.id !in execution.executedToolIds) {
        return TurnOutcome.Error(
            message = "complete_task was planned but did not execute",
            recoverable = true
        )
    }
    val decision = policy.decideCompletion(turnResult, arbitration)
    if (!decision.shouldComplete) return TurnOutcome.Continue
    return TurnOutcome.Complete(
        message = decision.summary ?: "Goal achieved",
        success = decision.success
    )
}
