package id.steveimm.pocketpilot.agent

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMStreamEvent
import id.steveimm.pocketpilot.llm.LLMToolCall
import id.steveimm.pocketpilot.llm.ResponsesResult
import id.steveimm.pocketpilot.tool.ToolExecutionContext
import id.steveimm.pocketpilot.tool.ToolExecutionResult
import id.steveimm.pocketpilot.tool.ToolInvocation
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolSpec
import id.steveimm.pocketpilot.tool.ValidationResult
import com.openai.models.responses.EasyInputMessage
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Test

class TurnToolFilteringTest {

    private val minimalInputItems = listOf(
        ResponseInputItem.ofEasyInputMessage(
            EasyInputMessage.builder()
                .role(EasyInputMessage.Role.USER)
                .content("Screen state (0 elements):\n```json\n[]\n```")
                .build()
        )
    )

    @Test
    fun `run exposes only allowed tools to llm`() = runTest {
        val llm =
                CapturingTurnLLMClient(
                        response =
                                ResponsesResult(
                                        textContent = "planning",
                                        toolCalls = emptyList(),
                                        responseId = "resp"
                                )
                )
        val registry =
                ToolRegistry().apply {
                    register(TestTurnTool("tap"))
                    register(TestTurnTool("open_app"))
                    register(TestTurnTool("open_app"))
                    register(TestTurnTool("read_screen"))
                }

        val turn =
                Turn(
                        toolRegistry = registry,
                        llmClient = llm,
                        allowedToolNames = setOf("open_app", "read_screen")
                )

        val result =
                turn.run(
                        model = "test-model",
                        systemPrompt = "planner",
                        inputItems = minimalInputItems
                )

        assertThat(result.toolCalls).isEmpty()
        assertThat(llm.lastToolNames)
                .containsExactly("open_app", "read_screen")
    }

    @Test
    fun `unavailable tools return explicit validation feedback`() = runTest {
        val llm =
                CapturingTurnLLMClient(
                        response =
                                ResponsesResult(
                                        textContent = null,
                                        toolCalls =
                                                listOf(
                                                        LLMToolCall(
                                                                callId = "call-1",
                                                                name = "tap",
                                                                arguments = "{}"
                                                        )
                                                ),
                                        responseId = "resp"
                                )
                )
        val registry =
                ToolRegistry().apply {
                    register(TestTurnTool("tap"))
                    register(TestTurnTool("open_app"))
                }

        val turn =
                Turn(
                        toolRegistry = registry,
                        llmClient = llm,
                        allowedToolNames = setOf("open_app")
                )

        val result =
                turn.run(
                        model = "test-model",
                        systemPrompt = "planner",
                        inputItems = minimalInputItems
                )

        assertThat(result.toolCalls.single().validationError).contains("Unavailable tool")
        assertThat(result.isComplete).isFalse()
    }

    @Test
    fun `run synthesizes non-empty tool call ids when provider returns blank id`() = runTest {
        val llm =
                CapturingTurnLLMClient(
                        response =
                                ResponsesResult(
                                        textContent = null,
                                        toolCalls =
                                                listOf(
                                                        LLMToolCall(
                                                                callId = "",
                                                                name = "tap",
                                                                arguments = "{}"
                                                        )
                                                ),
                                        responseId = "resp"
                                )
                )
        val registry = ToolRegistry().apply { register(TestTurnTool("tap")) }
        val turn = Turn(toolRegistry = registry, llmClient = llm)

        val result =
                turn.run(
                        model = "test-model",
                        systemPrompt = "planner",
                        inputItems = minimalInputItems
                )

        assertThat(result.toolCalls).hasSize(1)
        assertThat(result.toolCalls.single().id).isNotEmpty()
        assertThat(result.toolCalls.single().id).startsWith("call_")
    }

    @Test
    fun `run treats regular text as completion when no tool calls exist`() = runTest {
        val llm =
                CapturingTurnLLMClient(
                        response =
                                ResponsesResult(
                                        textContent = "Done. Task finished.",
                                        toolCalls = emptyList(),
                                        responseId = "resp"
                                )
                )
        val registry = ToolRegistry().apply { register(TestTurnTool("tap")) }
        val turn = Turn(toolRegistry = registry, llmClient = llm)

        val result =
                turn.run(
                        model = "test-model",
                        systemPrompt = "standalone",
                        inputItems = minimalInputItems
                )

        assertThat(result.toolCalls).isEmpty()
        assertThat(result.isComplete).isTrue()
        assertThat(result.content).isEqualTo("Done. Task finished.")
    }

    @Test
    fun `malformed arguments become explicit feedback without an executable fallback`() = runTest {
        for (args in listOf("{", "[]", "{x:1}", "null", "{\"x\":1} trailing")) {
            val llm = CapturingTurnLLMClient(ResponsesResult(null, listOf(LLMToolCall("id", "tap", args)), "r"))
            val result = Turn(ToolRegistry(), llm).run("test", minimalInputItems, "local")
            assertThat(result.toolCalls.single().validationError).contains("valid JSON object")
            assertThat(result.isComplete).isFalse()
        }
    }

    @Test
    fun `reasoning alone and invalid terminal responses cannot finish`() = runTest {
        val cases = listOf(
            listOf(LLMStreamEvent.ReasoningDelta("Need to inspect"), LLMStreamEvent.Completed()),
            listOf(LLMStreamEvent.TextDelta(" "), LLMStreamEvent.Completed()),
            listOf(LLMStreamEvent.TextDelta("Done")),
            listOf(LLMStreamEvent.TextDelta("Done"), LLMStreamEvent.Completed("length")),
            listOf(LLMStreamEvent.TextDelta("Done"), LLMStreamEvent.Completed("tool_calls")),
            listOf(LLMStreamEvent.TextDelta("Done"), LLMStreamEvent.Failed("Stream interrupted")),
        )
        for (events in cases) {
            val llm = CapturingTurnLLMClient(ResponsesResult(null, emptyList(), "r"), events)
            val output = Turn(ToolRegistry(), llm).runStreaming("test", minimalInputItems, "local").toList()
            assertThat(output.filterIsInstance<TurnStreamEvent.Complete>()).isEmpty()
            assertThat(output.filterIsInstance<TurnStreamEvent.Error>()).hasSize(1)
        }
    }

    @Test
    fun `native final text never executes tool syntax embedded in prose`() = runTest {
        val content = "The example is open_app{\"app_name\":\"Settings\"}."
        val llm = CapturingTurnLLMClient(ResponsesResult(content, emptyList(), "r"))
        val result = Turn(ToolRegistry(), llm).run("test", minimalInputItems, "local")
        assertThat(result.toolCalls).isEmpty()
        assertThat(result.content).isEqualTo(content)
        assertThat(result.isComplete).isTrue()
    }

    @Test
    fun `streaming retains unavailable calls for error feedback`() = runTest {
        val llm =
                CapturingTurnLLMClient(
                        response =
                                ResponsesResult(
                                        textContent = null,
                                        toolCalls = emptyList(),
                                        responseId = "resp"
                                ),
                        streamEvents =
                                listOf(
                                        LLMStreamEvent.ToolCallDone(
                                                LLMToolCall(
                                                        callId = "call-1",
                                                        name = "tap",
                                                        arguments = "{}"
                                                )
                                        ),
                                        LLMStreamEvent.Completed()
                                )
                )
        val registry =
                ToolRegistry().apply {
                    register(TestTurnTool("tap"))
                    register(TestTurnTool("open_app"))
                }
        val turn =
                Turn(
                        toolRegistry = registry,
                        llmClient = llm,
                        allowedToolNames = setOf("open_app")
                )

        val events =
                turn.runStreaming(
                                model = "test-model",
                                systemPrompt = "planner",
                                inputItems = minimalInputItems
                        )
                        .toList()

        assertThat(events.filterIsInstance<TurnStreamEvent.ToolCallReceived>()).hasSize(1)
        val complete = events.filterIsInstance<TurnStreamEvent.Complete>().single()
        assertThat(complete.result.toolCalls.single().validationError).contains("Unavailable tool")
    }
}

private class CapturingTurnLLMClient(
        private val response: ResponsesResult,
        private val streamEvents: List<LLMStreamEvent> = listOf(LLMStreamEvent.Completed())
) : LLMClient() {
    var lastToolNames: List<String> = emptyList()

    override suspend fun chatWithTools(
            systemPrompt: String,
            inputItems: List<ResponseInputItem>,
            tools: List<FunctionTool>,
            model: String,
        maxOutputTokens: Long?,
    ): ResponsesResult {
        lastToolNames = tools.map { it.name() }
        return response
    }

    override fun chatWithToolsStreaming(
            systemPrompt: String,
            inputItems: List<ResponseInputItem>,
            tools: List<FunctionTool>,
            model: String
    ): Flow<LLMStreamEvent> = flow {
        streamEvents.forEach { emit(it) }
    }
}

private class TestTurnTool(override val name: String) : ToolSpec {
    override val description: String = "test"
    override val parameterSchema: JSONObject =
            JSONObject().apply {
                put("type", "object")
                put("properties", JSONObject())
                put("required", JSONArray())
                put("additionalProperties", false)
            }

    override fun validate(params: JSONObject): ValidationResult = ValidationResult.Valid

    override fun createInvocation(params: JSONObject): ToolInvocation =
            object : ToolInvocation {
                override val toolName: String = name
                override val params: JSONObject = params
                override fun getDescription(): String = "test"
                override suspend fun execute(context: ToolExecutionContext): ToolExecutionResult {
                    return ToolExecutionResult.Success("ok")
                }
            }
}
