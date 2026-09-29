package id.steveimm.pocketpilot.history.model

internal fun List<ContentBlockRecord>.appendTextDelta(turnId: String, delta: String): List<ContentBlockRecord> {
    if (delta.isEmpty()) return this
    val index = indexOfLast { it is ContentBlockRecord.Text && it.turnId == turnId }
    if (index <= indexOfLast { it is ContentBlockRecord.Action }) return this + ContentBlockRecord.Text(delta, turnId)
    return toMutableList().apply {
        val existing = get(index) as ContentBlockRecord.Text
        set(index, existing.copy(text = existing.text + delta))
    }
}

internal fun List<ContentBlockRecord>.appendReasoningDelta(turnId: String, delta: String): List<ContentBlockRecord> {
    if (delta.isEmpty()) return this
    val index = indexOfLast { it is ContentBlockRecord.Reasoning && it.turnId == turnId }
    return toMutableList().apply {
        if (index > indexOfLast { it is ContentBlockRecord.Action }) {
            val existing = get(index) as ContentBlockRecord.Reasoning
            set(index, existing.copy(text = existing.text + delta))
        } else {
            val textIndex = indexOfLast { it is ContentBlockRecord.Text && it.turnId == turnId }
                .takeIf { it > indexOfLast { block -> block is ContentBlockRecord.Action } } ?: -1
            add(if (textIndex >= 0) textIndex else size, ContentBlockRecord.Reasoning(delta, turnId))
        }
    }
}

internal fun List<ContentBlockRecord>.withFinalAnswer(answer: String): List<ContentBlockRecord> {
    if (answer.isBlank()) return this
    val lastAction = indexOfLast { it is ContentBlockRecord.Action }
    return filterIndexed { index, block ->
        block !is ContentBlockRecord.FinalText && !(index > lastAction && block is ContentBlockRecord.Text)
    } + ContentBlockRecord.FinalText(answer)
}
