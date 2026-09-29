package id.steveimm.pocketpilot.agent.cognition.prompt

import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.history.MessageKind
import id.steveimm.pocketpilot.history.ResponseItem
import id.steveimm.pocketpilot.model.ScreenImage
import id.steveimm.pocketpilot.session.AgentSessionState
import com.openai.core.JsonValue
import com.openai.models.responses.EasyInputMessage
import com.openai.models.responses.ResponseFunctionToolCall
import com.openai.models.responses.ResponseInputContent
import com.openai.models.responses.ResponseInputImage
import com.openai.models.responses.ResponseInputItem
import com.openai.models.responses.ResponseInputText

/** Builds the complete input items list for one LLM turn. */
internal class PromptBuilder(
    private val historyManager: HistoryManager,
    private val sessionState: AgentSessionState,
    private val supportsVision: Boolean = true
) {

    /** Assemble all input items for one LLM call. */
    fun buildInputItems(
        observation: TurnObservation,
        warnings: List<String> = emptyList(),
        turnNumber: Int = 0,
        appSkill: String? = null,
        recalledMemory: String? = null,
        activatedAgentSkills: String? = null
    ): List<ResponseInputItem> = buildList {
        addAll(buildHistorySection())
        buildMemorySection()?.let { add(it) }
        recalledMemory?.trim()?.takeIf { it.isNotEmpty() }?.let { add(textUserMessage(it)) }
        appSkill?.trim()?.takeIf { it.isNotEmpty() }?.let { add(textUserMessage(it)) }
        activatedAgentSkills?.trim()?.takeIf { it.isNotEmpty() }?.let { add(textUserMessage(it)) }
        add(buildObservationSection(observation, warnings, turnNumber))
    }

    /** History section is a direct pass-through of [HistoryManager.forPrompt]. Screen compression is handled proactively by
     * HistoryManager on addItem(). */
    private fun buildHistorySection(): List<ResponseInputItem> {
        return historyManager.forPrompt().mapNotNull { it.toResponseInputItem() }
    }

    /** Build a single "Working Memory" user message (todos + scratchpad). Returns null when both are empty — no noise for early turns. */
    private fun buildMemorySection(): ResponseInputItem? {
        val text = buildMemoryText() ?: return null
        return textUserMessage(text)
    }

    /** Produces the text body for the memory message. Package-visible for testing. */
    internal fun buildMemoryText(): String? {
        val todoContext = sessionState.todos.toPromptContext()
        val scratchpadContext = sessionState.scratchpad.toPromptContext()
        val hasTodos = todoContext.isNotEmpty()
        val hasScratchpad = !scratchpadContext.startsWith("(empty)")

        if (!hasTodos && !hasScratchpad) return null

        return buildString {
            appendLine("## Working Memory")
            if (hasTodos) {
                appendLine()
                appendLine("### Todo List")
                append(todoContext)
            }
            if (hasScratchpad) {
                if (hasTodos) appendLine()
                appendLine()
                appendLine("### Scratchpad")
                append(scratchpadContext)
            }
        }.trim()
    }

    private fun buildObservationSection(
        observation: TurnObservation,
        warnings: List<String>,
        turnNumber: Int
    ): ResponseInputItem {
        val text = buildObservationText(observation, warnings, turnNumber)
        return if (observation.image != null && supportsVision) {
            imageUserMessage(text, observation.image)
        } else {
            textUserMessage(text)
        }
    }

    /** Produces the text body for the current-observation message. */
    internal fun buildObservationText(
        observation: TurnObservation,
        warnings: List<String>,
        turnNumber: Int = 0
    ): String {
        return buildString {
            if (turnNumber > 0) {
                appendLine("Turn $turnNumber")
                appendLine()
            }

            // Warnings — prime interpretation before JSON
            for (warning in warnings) {
                appendLine(warning)
            }
            if (warnings.isNotEmpty()) appendLine()

            // Screen state — canonical block shared with history.
            append(observation.screenBlock)
            if (!observation.hasAccessibility) {
                appendLine()
                append("Use coordinate-based actions (x, y) or analyze the screenshot visually.")
            }

            // Screenshot section
            if (observation.image != null && supportsVision) {
                if (observation.hasAccessibility) appendLine()
                appendLine()
                append("Screenshot attached (analyze visually if needed).")
            }
        }.trim()
    }

    private fun ResponseItem.toResponseInputItem(): ResponseInputItem? = when (this) {
        is ResponseItem.Message -> {
            val easyRole = when (role) {
                "user" -> EasyInputMessage.Role.USER
                "assistant" -> EasyInputMessage.Role.ASSISTANT
                else -> null
            }
            easyRole?.let { role ->
                val body = if (kind == MessageKind.COMPACTION_SUMMARY) {
                    "$CHECKPOINT_PREFIX$content"
                } else {
                    content
                }
                ResponseInputItem.ofEasyInputMessage(
                    EasyInputMessage.builder().role(role).content(body).apply {
                        reasoning?.let { putAdditionalProperty(it.field, JsonValue.from(it.content)) }
                    }.build()
                )
            }
        }
        is ResponseItem.FunctionCall -> ResponseInputItem.ofFunctionCall(
            ResponseFunctionToolCall.builder()
                .callId(id)
                .name(name)
                .arguments(arguments.toString())
                .build()
        )
        is ResponseItem.FunctionCallOutput -> ResponseInputItem.ofFunctionCallOutput(
            ResponseInputItem.FunctionCallOutput.builder()
                .callId(callId)
                .output(content)
                .build()
        )
    }

    private fun textUserMessage(text: String): ResponseInputItem =
        ResponseInputItem.ofEasyInputMessage(
            EasyInputMessage.builder()
                .role(EasyInputMessage.Role.USER)
                .content(text)
                .build()
        )

    private fun imageUserMessage(text: String, image: ScreenImage): ResponseInputItem =
        ResponseInputItem.ofEasyInputMessage(
            EasyInputMessage.builder()
                .role(EasyInputMessage.Role.USER)
                .contentOfResponseInputMessageContentList(
                    listOf(
                        ResponseInputContent.ofInputText(
                            ResponseInputText.builder().text(text).build()
                        ),
                        ResponseInputContent.ofInputImage(
                            ResponseInputImage.builder()
                                .detail(ResponseInputImage.Detail.AUTO)
                                .imageUrl(image.toDataUrl())
                                .build()
                        )
                    )
                )
                .build()
        )

    private companion object {
        const val CHECKPOINT_PREFIX =
            "[Context checkpoint from earlier work in this session]\n\n"
    }
}
