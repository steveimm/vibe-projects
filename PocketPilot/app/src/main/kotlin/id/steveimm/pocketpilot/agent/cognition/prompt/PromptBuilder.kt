package id.steveimm.pocketpilot.agent.cognition.prompt

import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.history.MessageKind
import id.steveimm.pocketpilot.history.ResponseItem
import id.steveimm.pocketpilot.model.ScreenImage
import com.openai.core.JsonValue
import com.openai.models.responses.EasyInputMessage
import com.openai.models.responses.ResponseFunctionToolCall
import com.openai.models.responses.ResponseInputContent
import com.openai.models.responses.ResponseInputImage
import com.openai.models.responses.ResponseInputItem
import com.openai.models.responses.ResponseInputText

/** Builds the complete input items list for one LLM turn. */
internal class PromptBuilder(
    private val historyManager: HistoryManager
) {

    /** Assemble all input items for one LLM call. */
    fun buildInputItems(
        observation: TurnObservation,
        warnings: List<String> = emptyList(),
        turnNumber: Int = 0,
    ): List<ResponseInputItem> = buildList {
        addAll(buildHistorySection())
        add(buildObservationSection(observation, warnings, turnNumber))
    }

    /** History section is a direct pass-through of [HistoryManager.forPrompt]. Screen compression is handled proactively by
     * HistoryManager on addItem(). */
    private fun buildHistorySection(): List<ResponseInputItem> {
        return historyManager.forPrompt().mapNotNull { it.toResponseInputItem() }
    }

    private fun buildObservationSection(
        observation: TurnObservation,
        warnings: List<String>,
        turnNumber: Int
    ): ResponseInputItem {
        val text = buildObservationText(observation, warnings, turnNumber)
        return if (observation.image != null) {
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

            append(observation.screenBlock)
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
