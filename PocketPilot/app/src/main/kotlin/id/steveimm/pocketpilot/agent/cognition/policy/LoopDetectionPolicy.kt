package id.steveimm.pocketpilot.agent.cognition.policy

import id.steveimm.pocketpilot.agent.cognition.context.LoopWarning
import id.steveimm.pocketpilot.agent.cognition.context.NavigationState
import id.steveimm.pocketpilot.agent.cognition.context.ScreenSignature

/** Thresholds for deciding whether the agent is stuck on UI navigation. */
internal data class LoopDetectionConfig(
    val similarityThreshold: Double = 0.95,
    val stableScreenWindow: Int = 5
)

/** Combined result of loop detection: the warning (if any). */
internal data class LoopDetectionResult(
    val warning: LoopWarning?
)

/** Detects "stuck" patterns from navigation history. */
internal class LoopDetectionPolicy(
    private val config: LoopDetectionConfig = LoopDetectionConfig()
) {
    fun detect(state: NavigationState): LoopDetectionResult {
        val recent = state.recentSignatures.takeLast(config.stableScreenWindow)
        if (recent.size == config.stableScreenWindow && recent.isStable(config.similarityThreshold)) {
            return LoopDetectionResult(
                warning = LoopWarning(
                    message = "Screen has not changed for ${config.stableScreenWindow} turns."
                )
            )
        }
        return LoopDetectionResult(warning = null)
    }
}

private fun List<ScreenSignature>.isStable(threshold: Double): Boolean {
    if (size < 2) return false
    return zipWithNext().all { (left, right) ->
        left.similarityTo(right) >= threshold
    }
}
