package id.steveimm.pocketpilot.agent

import id.steveimm.pocketpilot.llm.ModelReasoning
import android.util.Log
import id.steveimm.pocketpilot.history.CompactionOutcome
import id.steveimm.pocketpilot.history.Compactor
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.llm.ContextWindowExceededException
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMStreamEvent
import id.steveimm.pocketpilot.llm.LLMToolCall
import id.steveimm.pocketpilot.llm.classifyContextWindowExceeded
import id.steveimm.pocketpilot.tool.ToolRegistry
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import org.json.JSONObject

/** Encapsulates a single ReAct iteration: LLM call → response parsing. */
class Turn(
        private val toolRegistry: ToolRegistry,
        private val llmClient: LLMClient,
        private val allowedToolNames: Set<String>? = null,
        private val compactor: Compactor? = null,
        private val historyManager: HistoryManager? = null,
        private val currentGoal: (() -> String)? = null
) {
    companion object {
        private const val TAG = "Turn"
    }

    private data class TurnRequest(
            val inputItems: List<ResponseInputItem>,
            val tools: List<FunctionTool>,
            val model: String
    )

    suspend fun run(
            systemPrompt: String,
            inputItems: List<ResponseInputItem>,
            model: String
    ): TurnResult {
        val request = prepareRequest(inputItems, model)
        Log.d(TAG, "Running turn with ${request.inputItems.size} input items, model=$model")
        Log.d(TAG, "Using ${request.tools.size} tools: ${request.tools.map { it.name() }}")

        val response =
                llmClient.chatWithTools(
                        systemPrompt = systemPrompt,
                        inputItems = request.inputItems,
                        tools = request.tools,
                        model = request.model
                )

        Log.d(
                TAG,
                "LLM response: text=${response.textContent?.take(200)}, toolCalls=${response.toolCalls.size}"
        )
        return processResponse(response.textContent, response.toolCalls, response.reasoning, response.finishReason)
    }

    fun runStreaming(
            systemPrompt: String,
            inputItems: List<ResponseInputItem>,
            model: String,
            rebuildInputItems: (() -> List<ResponseInputItem>)? = null
    ): Flow<TurnStreamEvent> = flow {
        Log.d(TAG, "Running streaming turn with LLM streaming, model=$model")

        var currentInputItems = inputItems
        var attemptedRecovery = false
        while (true) {
            val contextWindowError: ContextWindowExceededException = try {
                streamOnce(systemPrompt, currentInputItems, model) { event -> emit(event) }
                return@flow
            } catch (e: ContextWindowExceededException) {
                e
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // Some servers surface overflow as a Failed event whose message bubbles up as an unclassified
                // RuntimeException. Re-classify here so we route to compaction instead of treating it as a generic terminal error.
                val reclassified = classifyContextWindowExceeded(e)
                if (reclassified != null) {
                    reclassified
                } else {
                    Log.e(TAG, "Streaming turn failed", e)
                    emit(TurnStreamEvent.Error(e))
                    return@flow
                }
            }

            val cap = compactor
            val hm = historyManager
            val goalFn = currentGoal
            if (attemptedRecovery || cap == null || hm == null || goalFn == null) {
                if (attemptedRecovery) {
                    Log.e(TAG, "Context-window exceeded after reactive compaction; propagating", contextWindowError)
                } else {
                    Log.e(
                            TAG,
                            "Context-window exceeded but no compactor wiring available; propagating",
                            contextWindowError
                    )
                }
                emit(TurnStreamEvent.Error(contextWindowError))
                return@flow
            }
            attemptedRecovery = true
            Log.w(TAG, "Context-window exceeded; running reactive compaction and retrying", contextWindowError)
            val outcome = cap.forceCompactNow(goalFn.invoke(), hm)
            Log.i(TAG, "Reactive compaction outcome: $outcome")
            when (outcome) {
                is CompactionOutcome.Compacted -> {
                    if (rebuildInputItems == null) {
                        Log.e(
                                TAG,
                                "Compaction succeeded but no rebuildInputItems provided; cannot retry with shrunken history"
                        )
                        emit(
                                TurnStreamEvent.Error(
                                        ContextWindowExceededException(
                                                "Compaction succeeded but caller did not supply rebuildInputItems; cannot retry",
                                                cause = contextWindowError
                                        )
                                )
                        )
                        return@flow
                    }
                    currentInputItems = rebuildInputItems.invoke()
                    // Loop continues for one retry with the fresh prompt.
                }
                is CompactionOutcome.Failed,
                CompactionOutcome.Stale,
                CompactionOutcome.NothingToCompact,
                CompactionOutcome.Skipped -> {
                    val why = when (outcome) {
                        is CompactionOutcome.Failed -> "Failed(${outcome.reason})"
                        CompactionOutcome.Stale -> "Stale"
                        CompactionOutcome.NothingToCompact -> "NothingToCompact"
                        CompactionOutcome.Skipped -> "Skipped"
                    }
                    emit(
                            TurnStreamEvent.Error(
                                    ContextWindowExceededException(
                                            "Compaction could not reduce history below context window (outcome=$why)",
                                            cause = contextWindowError
                                    )
                            )
                    )
                    return@flow
                }
            }
        }
    }

    private suspend fun streamOnce(
            systemPrompt: String,
            inputItems: List<ResponseInputItem>,
            model: String,
            emit: suspend (TurnStreamEvent) -> Unit
    ) {
        val request = prepareRequest(inputItems, model)
        Log.d(TAG, "Streaming turn with ${request.inputItems.size} input items")

        val textAccumulator = StringBuilder()
        val reasoningAccumulator = StringBuilder()
        var reasoningField = "reasoning"
        var finishReason: String? = null
        val toolCalls = mutableListOf<LLMToolCall>()

        llmClient.chatWithToolsStreaming(
                        systemPrompt = systemPrompt,
                        inputItems = request.inputItems,
                        tools = request.tools,
                        model = request.model
                )
                .collect { event ->
                    when (event) {
                        is LLMStreamEvent.Created -> {
                            Log.d(TAG, "Response created with ID: ${event.responseId}")
                        }
                        is LLMStreamEvent.ReasoningDelta -> {
                            reasoningAccumulator.append(event.delta)
                            reasoningField = event.field
                            emit(TurnStreamEvent.ReasoningDelta(event.delta))
                        }
                        is LLMStreamEvent.TextDelta -> {
                            textAccumulator.append(event.delta)
                            emit(TurnStreamEvent.TextDelta(event.delta))
                        }
                        is LLMStreamEvent.ToolCallDone -> {
                            val llmToolCall = event.toolCall.let { if (it.callId.isBlank()) it.copy(callId = "call_${UUID.randomUUID()}") else it }
                            toolCalls.add(llmToolCall)

                            Log.d(
                                    TAG,
                                    "Received tool call: ${llmToolCall.name} with id ${llmToolCall.callId}"
                            )

                            emit(TurnStreamEvent.ToolCallReceived(convertToToolCallRequest(llmToolCall)))
                        }
                        is LLMStreamEvent.Completed -> {
                            finishReason = event.finishReason
                        }
                        is LLMStreamEvent.Failed -> {
                            Log.e(TAG, event.error)
                            classifyContextWindowExceeded(event.error)?.let { throw it }
                            throw RuntimeException(event.error)
                        }
                    }
                }

        val textContent = textAccumulator.toString().takeIf { it.isNotEmpty() }
        val reasoning = reasoningAccumulator.toString().takeIf { it.isNotEmpty() }?.let { ModelReasoning(it, reasoningField) }
        val result = processResponse(textContent, toolCalls, reasoning, finishReason)

        Log.d(
                TAG,
                "Streaming turn complete: text=${textContent?.take(100)}..., toolCalls=${toolCalls.size}"
        )
        emit(TurnStreamEvent.Complete(result))
    }

    private fun convertToToolCallRequest(llmToolCall: LLMToolCall): ToolCallRequest {
        val id = llmToolCall.callId.ifBlank { "call_${UUID.randomUUID()}" }
        var error: String? = null
        val args = try {
            val element = kotlinx.serialization.json.Json.parseToJsonElement(llmToolCall.arguments)
            require(element is kotlinx.serialization.json.JsonObject)
            JSONObject(llmToolCall.arguments)
        } catch (_: Exception) {
            error = "Arguments for ${llmToolCall.name} must be a valid JSON object. No action was executed."
            JSONObject()
        }
        if (allowedToolNames?.contains(llmToolCall.name) == false) {
            error = "Unavailable tool: ${llmToolCall.name}. Available tools: ${allowedToolNames.joinToString()}. No action was executed."
        }
        return ToolCallRequest(id, llmToolCall.name, args, error)
    }

    private fun prepareRequest(
            inputItems: List<ResponseInputItem>,
            model: String
    ): TurnRequest {
        val tools =
                toolRegistry.generateResponsesApiTools { spec ->
                    allowedToolNames?.contains(spec.name) != false
                }
        return TurnRequest(inputItems = inputItems, tools = tools, model = model)
    }

    private fun processResponse(
        textContent: String?,
        llmToolCalls: List<LLMToolCall>,
        reasoning: ModelReasoning?,
        finishReason: String?,
    ): TurnResult {
        require(finishReason in setOf("stop", "tool_calls")) { "Model response did not finish normally: $finishReason" }
        val calls = llmToolCalls.map(::convertToToolCallRequest)
        val finalResponse = llmToolCalls.isEmpty() && finishReason == "stop" && !textContent.isNullOrBlank()
        require(llmToolCalls.isNotEmpty() || finalResponse) { "Model returned no tool call or final answer" }
        return TurnResult(textContent, calls, finalResponse, reasoning)
    }
}

sealed interface TurnStreamEvent {
    data class ReasoningDelta(val delta: String) : TurnStreamEvent
    data class TextDelta(val text: String) : TurnStreamEvent
    data class ToolCallReceived(val toolCall: ToolCallRequest) : TurnStreamEvent
    data class Complete(val result: TurnResult) : TurnStreamEvent
    data class Error(val error: Throwable) : TurnStreamEvent
}

data class TurnResult(
        val content: String?,
        val toolCalls: List<ToolCallRequest>,
        val isComplete: Boolean,
        val reasoning: ModelReasoning? = null,
)

data class ToolCallRequest(val id: String, val name: String, val arguments: JSONObject, val validationError: String? = null)
