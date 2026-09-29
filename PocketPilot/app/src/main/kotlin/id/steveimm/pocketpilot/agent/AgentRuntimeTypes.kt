package id.steveimm.pocketpilot.agent

import id.steveimm.pocketpilot.agent.cognition.context.NavigationState
import id.steveimm.pocketpilot.tool.ToolCallResult

/** Reason why the agent stopped. */
sealed class AgentStopReason {
    data class Finished(val message: String = "") : AgentStopReason()
    data object UserRequested : AgentStopReason()
    data class Error(val message: String) : AgentStopReason()
}

/** Outcome of a single turn. */
sealed class TurnOutcome {
    data object Continue : TurnOutcome()
    data class Complete(val message: String) : TurnOutcome()
    data class ToolFailed(val message: String) : TurnOutcome()
    data class Error(val message: String, val recoverable: Boolean) : TurnOutcome()
    data object Cancelled : TurnOutcome()
}

/** Mutable runtime state carried across turns. */
internal data class TurnRunnerState(
    val navigationState: NavigationState = NavigationState(),
    val observeScreen: Boolean = false,
)

/** Full output of one `AgentTurnRunner.executeTurn()` call: - `outcome`: control decision for the outer Agent loop - `nextState`: state
 * to feed into the next turn */
internal data class TurnExecutionResult(
    val outcome: TurnOutcome,
    val nextState: TurnRunnerState
)

/** Outcome of executing the selected tool calls for a turn. */
internal data class ExecutionPhaseResult(
    val terminatedEarly: Boolean,
    val lastTerminalResult: ToolCallResult?
) {
    companion object {
        val EMPTY = ExecutionPhaseResult(
            terminatedEarly = false,
            lastTerminalResult = null
        )
    }
}

/** Maps the planning + execution results to the control-loop outcome. */
internal fun decideTurnOutcome(
    turnResult: TurnResult,
    execution: ExecutionPhaseResult
): TurnOutcome {
    if (execution.terminatedEarly) {
        return when (val last = execution.lastTerminalResult) {
            is ToolCallResult.Cancelled -> TurnOutcome.Cancelled
            is ToolCallResult.Error -> TurnOutcome.ToolFailed(last.error)
            else -> TurnOutcome.Error(
                message = "Tool execution aborted before completion",
                recoverable = true
            )
        }
    }
    return if (turnResult.isComplete) TurnOutcome.Complete(requireNotNull(turnResult.content)) else TurnOutcome.Continue
}

internal fun AgentStopReason.label(): String = when (this) {
    is AgentStopReason.Finished -> "finished"
    AgentStopReason.UserRequested -> "user_stopped"
    is AgentStopReason.Error -> "error"
}
