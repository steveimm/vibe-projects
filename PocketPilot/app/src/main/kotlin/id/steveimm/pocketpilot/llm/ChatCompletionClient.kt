package id.steveimm.pocketpilot.llm

import android.util.Log
import com.openai.client.OpenAIClient
import com.openai.client.OpenAIClientImpl
import com.openai.core.ClientOptions
import com.openai.core.RequestOptions
import com.openai.core.http.HttpClient
import com.openai.core.http.HttpRequest
import com.openai.client.okhttp.OkHttpClient
import com.openai.models.ChatModel
import com.openai.models.chat.completions.ChatCompletionCreateParams
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.channels.trySendBlocking
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicReference

/** LLM client using OpenAI Chat Completions API. */
class ChatCompletionClient(
    baseUrl: String,
    apiKey: String = "",
) : LLMClient() {
    companion object {
        private const val TAG = "ChatCompletionClient"
    }

    private val client: OpenAIClient = createClient(ServerBaseUrlValidator.validate(baseUrl).getOrThrow(), apiKey)

    private fun createClient(baseUrl: String, apiKey: String): OpenAIClient {
        val transport = OkHttpClient.builder().apply {
            InsecureSslConfig.sslSocketFactory?.let { sslSocketFactory(it) }
            InsecureSslConfig.trustManager?.let { trustManager(it) }
        }.build()
        val serverTransport = if (apiKey.isNotBlank()) transport else object : HttpClient by transport {
            override fun execute(request: HttpRequest, requestOptions: RequestOptions) =
                transport.execute(request.toBuilder().removeHeaders("Authorization").build(), requestOptions)

            override fun executeAsync(request: HttpRequest, requestOptions: RequestOptions) =
                transport.executeAsync(request.toBuilder().removeHeaders("Authorization").build(), requestOptions)
        }
        return OpenAIClientImpl(ClientOptions.builder().httpClient(serverTransport).baseUrl(baseUrl).apiKey(apiKey).build())
    }

    override suspend fun chatWithTools(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String,
        maxOutputTokens: Long?,
    ): ResponsesResult = withContext(Dispatchers.IO) {
        LlmRetry.executeWithRetry(
                tag = TAG,
                operationName = "chat-completions chatWithTools"
        ) {
            executeChatWithTools(systemPrompt, inputItems, tools, model, maxOutputTokens)
        }
    }

    private fun executeChatWithTools(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String,
        maxOutputTokens: Long?,
    ): ResponsesResult {
        Log.d(TAG, "Calling Chat Completions API with ${inputItems.size} input items, ${tools.size} tools")
        LlmLogger.logInput(TAG, systemPrompt, inputItems, tools)

        try {
            val params = buildParams(systemPrompt, inputItems, tools, model, maxOutputTokens)
            val response = client.chat().completions().create(params)

            val choice = response.choices().firstOrNull()
                ?: return ResponsesResult(textContent = null, toolCalls = emptyList(), responseId = response.id())

            val message = choice.message()
            val textContent = message.content().orElse(null)
            val toolCalls = message.toolCalls().orElse(emptyList())
                .filter { it.isFunction() }
                .map { tc ->
                    val func = tc.asFunction()
                    LLMToolCall(
                        callId = func.id(),
                        name = func.function().name(),
                        arguments = func.function().arguments()
                    )
                }

            val result = ResponsesResult(
                textContent = textContent,
                toolCalls = toolCalls,
                responseId = response.id(),
                reasoning = readModelReasoning(message._additionalProperties()),
            )
            Log.d(TAG, "Chat API result: ${result.textContent?.take(200)}, ${result.toolCalls.size} tool calls")
            LlmLogger.logOutput(TAG, result)
            return result
        } catch (e: Exception) {
            throw OpenAIErrorClassifier.classify(e)
        }
    }

    override fun chatWithToolsStreaming(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String
    ): Flow<LLMStreamEvent> = callbackFlow {
        Log.d(TAG, "Starting streaming Chat Completions with ${inputItems.size} input items")
        LlmLogger.logInput(TAG, systemPrompt, inputItems, tools)

        val activeStream = AtomicReference<AutoCloseable?>(null)

        val job = launch(Dispatchers.IO) {
            val retryResult =
                streamWithRetry(
                    tag = TAG,
                    emitToFlow = { event -> trySendBlocking(event).getOrThrow() }
                ) { attempt, emitter ->
                val verbose = LlmLogger.isVerboseEnabled
                val textAccumulator = if (verbose) StringBuilder() else null
                // Map: tool call index → (callId, name, argsBuilder)
                val toolCallBuilders = mutableMapOf<Long, Triple<String, String, StringBuilder>>()
                val completedToolCalls = if (verbose) mutableListOf<LLMToolCall>() else null
                var responseId: String? = null
                var sawFinishReason = false

                val params = buildParams(systemPrompt, inputItems, tools, model)
                Log.d(TAG, "Making streaming Chat API call (attempt $attempt)")

                withContext(Dispatchers.IO) {
                    val streamResponse = client.chat().completions().createStreaming(params)
                    activeStream.set(streamResponse)
                    try {
                        streamResponse.use { stream ->
                                currentCoroutineContext().ensureActive()
                            stream.stream().forEach { chunk ->
                            if (responseId == null) {
                                responseId = chunk.id()
                                emitter.emit(LLMStreamEvent.Created(chunk.id()))
                            }

                            for (choice in chunk.choices()) {
                                val delta = choice.delta()

                                // Text content delta
                                delta.content().ifPresent { text ->
                                    if (text.isNotEmpty()) {
                                        textAccumulator?.append(text)
                                        emitter.emit(LLMStreamEvent.TextDelta(text))
                                    }
                                }

                                readModelReasoning(delta._additionalProperties())?.let {
                                    emitter.emit(LLMStreamEvent.ReasoningDelta(it.content, it.field))
                                }

                                // Tool call deltas (streamed incrementally)
                                delta.toolCalls().ifPresent { calls ->
                                    for (tcDelta in calls) {
                                        val idx = tcDelta.index()

                                        if (!toolCallBuilders.containsKey(idx)) {
                                            toolCallBuilders[idx] =
                                                Triple(
                                                    tcDelta.id().orElse("call_$idx"),
                                                    tcDelta.function().orElse(null)?.name()?.orElse("")
                                                        ?: "",
                                                    StringBuilder()
                                                )
                                        } else {
                                            // Update id/name if provided in a later delta
                                            tcDelta.id().ifPresent { id ->
                                                val (curId, name, args) = toolCallBuilders[idx]!!
                                                if (curId.startsWith("call_")) {
                                                    toolCallBuilders[idx] = Triple(id, name, args)
                                                }
                                            }
                                            tcDelta.function().orElse(null)?.name()?.ifPresent { name ->
                                                val (curId, curName, args) = toolCallBuilders[idx]!!
                                                if (curName.isEmpty()) {
                                                    toolCallBuilders[idx] = Triple(curId, name, args)
                                                }
                                            }
                                        }

                                        tcDelta.function().ifPresent { func ->
                                            func.arguments().ifPresent { argFragment ->
                                                toolCallBuilders[idx]?.let { (_, _, argsBuilder) ->
                                                    argsBuilder.append(argFragment)
                                                }
                                            }
                                        }
                                    }
                                }

                                // Emit completed tool calls when finish reason received
                                choice.finishReason().ifPresent { reason ->
                                    when (reason.toString()) {
                                        "stop", "tool_calls" -> {
                                            sawFinishReason = true
                                            for ((_, builder) in toolCallBuilders) {
                                                val (callId, name, args) = builder
                                                val toolCall =
                                                    LLMToolCall(
                                                        callId = callId,
                                                        name = name,
                                                        arguments = args.toString()
                                                    )
                                                completedToolCalls?.add(toolCall)
                                                emitter.emit(LLMStreamEvent.ToolCallDone(toolCall))
                                            }
                                            toolCallBuilders.clear()
                                        }
                                        "length" -> {
                                            throw TransientException("Response truncated (finish_reason=length)")
                                        }
                                        "content_filter" -> {
                                            sawFinishReason = true
                                            emitter.emit(LLMStreamEvent.Failed("Response blocked by content filter"))
                                        }
                                        else -> {
                                            sawFinishReason = true
                                        }
                                    }
                                }
                            }
                        }
                            }
                        } finally {
                            activeStream.set(null)
                        }
                    }

                    // Stream ended — require terminal completion
                    if (!sawFinishReason) {
                        throw TransientException("Stream ended without finish_reason")
                    }
                    if (verbose && textAccumulator != null && completedToolCalls != null) {
                        LlmLogger.logOutput(
                            TAG,
                            ResponsesResult(
                                textContent = textAccumulator.toString().takeIf { it.isNotEmpty() },
                                toolCalls = completedToolCalls,
                                responseId = responseId ?: "unknown"
                            )
                        )
                    }
                    emitter.emit(LLMStreamEvent.Completed)
                }

            retryResult.closeFlow(
                emitToFlow = { trySendBlocking(it).getOrThrow() },
                closeFlow = { close() }
            )
        }

        awaitClose {
            activeStream.getAndSet(null)?.runCatching { close() }
            job.cancel()
            Log.d(TAG, "Streaming flow closed")
        }
    }

    private fun buildParams(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String,
        maxOutputTokens: Long? = null,
    ): ChatCompletionCreateParams {
        val messages = buildList {
            add(ChatCompletionInterop.systemMessage(systemPrompt))
            addAll(ChatCompletionInterop.convertInputItems(inputItems))
        }
        val chatTools = ChatCompletionInterop.convertTools(tools)

        val builder = ChatCompletionCreateParams.builder()
            .model(ChatModel.of(model))
            .messages(messages)
            .tools(chatTools)

        maxOutputTokens?.let { builder.maxCompletionTokens(it) }

        return builder.build()
    }

    override suspend fun cleanup() {
        withContext(Dispatchers.IO) { client.close() }
    }
}
