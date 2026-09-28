package id.steveimm.pocketpilot.tool.action

import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.platform.AndroidPlatform
import id.steveimm.pocketpilot.platform.UIAction
import id.steveimm.pocketpilot.tool.AppClassifier

/** Long press executor: thin wrapper over [executePointAction]. */
class LongPressExecutor(
    private val targetResolver: TargetResolver = TargetResolver
) {
    suspend fun execute(
        target: Target,
        durationMs: Long,
        snapshot: ScreenSnapshot?,
        platform: AndroidPlatform,
        isCancelled: () -> Boolean,
        appClassifier: AppClassifier? = null
    ): ActionOutcome = executePointAction(
        actionName = "long_press",
        channels = ActionPriorityOrder.longPress.map { channel ->
            when (channel) {
                ActionPriorityOrder.LongPressChannel.NODE_LONG_CLICK -> ChannelAttempt(
                    displayName = "node_action_long_click",
                    requiresSemantic = true
                ) { pt, hint -> UIAction.LongClickNodeAt(pt.x, pt.y, hint) }
                ActionPriorityOrder.LongPressChannel.GESTURE_LONG_PRESS -> ChannelAttempt(
                    displayName = "gesture_long_press",
                    requiresSemantic = false
                ) { pt, _ -> UIAction.LongPressAt(pt.x, pt.y, durationMs) }
            }
        },
        target = target,
        snapshot = snapshot,
        platform = platform,
        isCancelled = isCancelled,
        formatSuccess = { point, channel, warnings ->
            formatActionMessage(
                "Long pressed (${point.x},${point.y}) for ${durationMs}ms via $channel",
                warnings
            )
        },
        formatFailure = { point, channel, reason, warnings ->
            formatActionMessage(
                "Long press at (${point.x},${point.y}) for ${durationMs}ms via $channel failed: $reason",
                warnings
            )
        },
        targetResolver = targetResolver,
        appClassifier = appClassifier
    )
}
