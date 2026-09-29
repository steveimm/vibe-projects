package id.steveimm.pocketpilot.agent

import id.steveimm.pocketpilot.history.Compactor
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMStreamEvent
import id.steveimm.pocketpilot.llm.ModelEntry
import id.steveimm.pocketpilot.llm.ResponsesResult
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

/** Builds a no-op-in-practice [Compactor] for tests that aren't focused on compaction. */
internal fun noopCompactor(
    llmClient: LLMClient = SkippedLLMClient,
    contextWindow: Int = 128_000,
): Compactor = Compactor(
    llmClient = llmClient,
    model = ModelEntry(
        name = "test-model",
        displayName = "Test Model",
        modelId = "test-model",
        contextWindow = contextWindow,
    ),
    initialPrompt = "",
    updatePrompt = "",
)

internal object SkippedLLMClient : LLMClient() {
    override suspend fun chatWithTools(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String,
        maxOutputTokens: Long?,
    ): ResponsesResult = ResponsesResult(textContent = null, toolCalls = emptyList(), responseId = "noop")

    override fun chatWithToolsStreaming(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String
    ): Flow<LLMStreamEvent> = flow { emit(LLMStreamEvent.Completed()) }
}
