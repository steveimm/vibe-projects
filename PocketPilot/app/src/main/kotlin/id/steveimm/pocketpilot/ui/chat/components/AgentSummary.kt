package id.steveimm.pocketpilot.ui.chat.components

import id.steveimm.pocketpilot.ui.chat.model.ChatMessage
import id.steveimm.pocketpilot.ui.chat.model.ContentBlock

internal fun outcomeFooter(message: ChatMessage.Agent): String {
    val actionCount = countActions(message)
    val elapsed = formatElapsed(message)
    val parts = buildList {
        if (message.contentBlocks.any { it is ContentBlock.Reasoning }) add("Reasoning")
        if (actionCount > 0) add("$actionCount action${if (actionCount == 1) "" else "s"}")
        if (isEmpty()) add("Activity")
        elapsed?.let { add(it) }
    }
    return parts.joinToString(separator = " · ")
}

internal fun countActions(message: ChatMessage.Agent): Int =
    message.contentBlocks.count { it is ContentBlock.Action }

internal fun formatElapsed(message: ChatMessage.Agent): String? {
    val end = message.completedTimestamp ?: return null
    val deltaMs = (end - message.timestamp).coerceAtLeast(0)
    return when {
        deltaMs < 10_000 -> String.format("%.1fs", deltaMs / 1000.0)
        else -> "${deltaMs / 1000}s"
    }
}
