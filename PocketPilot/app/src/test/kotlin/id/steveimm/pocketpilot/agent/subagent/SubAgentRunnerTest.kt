package id.steveimm.pocketpilot.agent.subagent

import id.steveimm.pocketpilot.test.testModelCatalog

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.agent.AgentEventDispatcher
import id.steveimm.pocketpilot.agent.AgentExecutionRole
import id.steveimm.pocketpilot.agent.definition.AgentRoleDef
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.LLMStreamEvent
import id.steveimm.pocketpilot.llm.LLMToolCall
import id.steveimm.pocketpilot.llm.ResponsesResult
import id.steveimm.pocketpilot.protocol.ActionExecuted
import id.steveimm.pocketpilot.protocol.ActionOutcome
import id.steveimm.pocketpilot.protocol.ActionProposed
import id.steveimm.pocketpilot.protocol.AgentEvent
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionId
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
import id.steveimm.pocketpilot.session.AgentSessionState
import id.steveimm.pocketpilot.session.SessionServices
import id.steveimm.pocketpilot.test.FakeAndroidPlatform
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.PolicyEngine
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolRouter
import id.steveimm.pocketpilot.tool.impl.CompleteTaskTool
import id.steveimm.pocketpilot.trace.NoopTraceRecorder
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SubAgentRunnerTest {

        @Test
        fun `runner returns success when child reaches goal`() = runTest {
                val services = buildServices(SubAgentTestLLMClient(delayMs = 0))
                val runner =
                        IsolatedSubAgentRunner(
                                roleDef =
                                        AgentRoleDef(
                                                name = "executor",
                                                executionRole = AgentExecutionRole.SUBAGENT,
                                                description = "Exec",
                                                systemPrompt = "prompt",
                                                allowedTools = emptySet(),
                                                timeoutMs = 5_000
                                        ),
                                parentServices = services,
                                parentSessionId = SessionId("session-1"),
                                eventDispatcher = AgentEventDispatcher(SessionId("session-1")) {},
                                parentEventEmitter = {}
                        )

                val result = runner.run(SubAgentRequest(query = "do it"))

                assertThat(result.success).isTrue()
        }

        @Test
        fun `runner forwards child action events to parent emitter unchanged`() = runTest {
                val llm =
                        ScriptedSubAgentLLMClient(
                                events =
                                        listOf(
                                                LLMStreamEvent.ToolCallDone(
                                                        LLMToolCall(
                                                                callId = "call-1",
                                                                name = "complete_task",
                                                                arguments =
                                                                        "{\"status\":\"success\",\"answer\":\"done\"}"
                                                        )
                                                ),
                                                LLMStreamEvent.Completed
                                        )
                        )
                val services = buildServices(llm, includeCompleteTask = true)
                val parentEvents = mutableListOf<AgentEvent>()
                val runner =
                        IsolatedSubAgentRunner(
                                roleDef =
                                        AgentRoleDef(
                                                name = "executor",
                                                executionRole = AgentExecutionRole.SUBAGENT,
                                                description = "Exec",
                                                systemPrompt = "prompt",
                                                allowedTools = setOf("complete_task"),
                                                timeoutMs = 5_000
                                        ),
                                parentServices = services,
                                parentSessionId = SessionId("session-1"),
                                eventDispatcher = AgentEventDispatcher(SessionId("session-1")) {},
                                parentEventEmitter = { parentEvents.add(it) }
                        )

                val result = runner.run(SubAgentRequest(query = "do it"))

                assertThat(result.success).isTrue()
                val proposed = parentEvents.filterIsInstance<ActionProposed>().single()
                val executed = parentEvents.filterIsInstance<ActionExecuted>().single()
                assertThat(proposed.sessionId.value).startsWith("session-1::sub-executor-")
                assertThat(proposed.actionId).isEqualTo("call-1")
                assertThat(proposed.toolName).isEqualTo("complete_task")
                assertThat(proposed.description).contains("done")
                assertThat(executed.sessionId).isEqualTo(proposed.sessionId)
                assertThat(executed.actionId).isEqualTo("call-1")
                assertThat(executed.toolName).isEqualTo("complete_task")
                assertThat(executed.outcome).isEqualTo(ActionOutcome.SUCCESS)
        }

        @Test
        fun `runner drops excluded subagent tool calls before routing`() = runTest {
                val llm =
                        ScriptedSubAgentLLMClient(
                                events =
                                        listOf(
                                                LLMStreamEvent.ToolCallDone(
                                                        LLMToolCall(
                                                                callId = "call-delegate",
                                                                name = "delegate_task",
                                                                arguments = "{\"query\":\"nested\"}"
                                                        )
                                                ),
                                                LLMStreamEvent.ToolCallDone(
                                                        LLMToolCall(
                                                                callId = "call-memory",
                                                                name = "remember_experience",
                                                                arguments =
                                                                        "{\"scope\":\"user\",\"section\":\"facts\",\"content\":\"x\"}"
                                                        )
                                                ),
                                                LLMStreamEvent.Completed
                                        )
                        )
                val services = buildServices(llm)
                val parentEvents = mutableListOf<AgentEvent>()
                val runner =
                        IsolatedSubAgentRunner(
                                roleDef =
                                        AgentRoleDef(
                                                name = "executor",
                                                executionRole = AgentExecutionRole.SUBAGENT,
                                                description = "Exec",
                                                systemPrompt = "prompt",
                                                allowedTools = setOf("delegate_task", "remember_experience"),
                                                timeoutMs = 5_000
                                        ),
                                parentServices = services,
                                parentSessionId = SessionId("session-1"),
                                eventDispatcher = AgentEventDispatcher(SessionId("session-1")) {},
                                parentEventEmitter = { parentEvents.add(it) }
                        )

                val result = runner.run(SubAgentRequest(query = "do it"))

                assertThat(result.success).isFalse()
                assertThat(parentEvents.filterIsInstance<ActionProposed>()).isEmpty()
                assertThat(parentEvents.filterIsInstance<ActionExecuted>()).isEmpty()
        }

        @Test
        fun `runner returns timeout when child exceeds timeout`() = runTest {
                val services = buildServices(SubAgentTestLLMClient(delayMs = 200))
                val events = mutableListOf<AgentEvent>()
                val runner =
                        IsolatedSubAgentRunner(
                                roleDef =
                                        AgentRoleDef(
                                                name = "executor",
                                                executionRole = AgentExecutionRole.SUBAGENT,
                                                description = "Exec",
                                                systemPrompt = "prompt",
                                                allowedTools = emptySet(),
                                                timeoutMs = 10
                                        ),
                                parentServices = services,
                                parentSessionId = SessionId("session-1"),
                                eventDispatcher = AgentEventDispatcher(SessionId("session-1")) { events.add(it) },
                                parentEventEmitter = {}
                        )

                val result = runner.run(SubAgentRequest(query = "do it"))

                assertThat(result.success).isFalse()
                assertThat(result.message).contains("Timeout")
        }

        @Test
        fun `runner forwards complete_task success answer`() = runTest {
                val llm =
                        ScriptedSubAgentLLMClient(
                                events =
                                        listOf(
                                                LLMStreamEvent.ToolCallDone(
                                                        LLMToolCall(
                                                                callId = "call-1",
                                                                name = "complete_task",
                                                                arguments =
                                                                        "{\"status\":\"success\",\"answer\":\"Email summary captured\"}"
                                                        )
                                                ),
                                                LLMStreamEvent.Completed
                                        )
                        )
                val services = buildServices(llm, includeCompleteTask = true)
                val runner =
                        IsolatedSubAgentRunner(
                                roleDef =
                                        AgentRoleDef(
                                                name = "executor",
                                                executionRole = AgentExecutionRole.SUBAGENT,
                                                description = "Exec",
                                                systemPrompt = "prompt",
                                                allowedTools = setOf("complete_task"),
                                                timeoutMs = 5_000
                                        ),
                                parentServices = services,
                                parentSessionId = SessionId("session-1"),
                                eventDispatcher = AgentEventDispatcher(SessionId("session-1")) {},
                                parentEventEmitter = {}
                        )

                val result = runner.run(SubAgentRequest(query = "do it"))

                assertThat(result.success).isTrue()
                assertThat(result.message).contains("Email summary captured")
        }

        @Test
        fun `runner maps complete_task failure status to failed result`() = runTest {
                val llm =
                        ScriptedSubAgentLLMClient(
                                events =
                                        listOf(
                                                LLMStreamEvent.ToolCallDone(
                                                        LLMToolCall(
                                                                callId = "call-1",
                                                                name = "complete_task",
                                                                arguments =
                                                                        "{\"status\":\"failure\",\"answer\":\"Could not find Notion app: Not installed\"}"
                                                        )
                                                ),
                                                LLMStreamEvent.Completed
                                        )
                        )
                val services = buildServices(llm, includeCompleteTask = true)
                val runner =
                        IsolatedSubAgentRunner(
                                roleDef =
                                        AgentRoleDef(
                                                name = "executor",
                                                executionRole = AgentExecutionRole.SUBAGENT,
                                                description = "Exec",
                                                systemPrompt = "prompt",
                                                allowedTools = setOf("complete_task"),
                                                timeoutMs = 5_000
                                        ),
                                parentServices = services,
                                parentSessionId = SessionId("session-1"),
                                eventDispatcher = AgentEventDispatcher(SessionId("session-1")) {},
                                parentEventEmitter = {}
                        )

                val result = runner.run(SubAgentRequest(query = "do it"))

                assertThat(result.success).isFalse()
                assertThat(result.message).contains("Could not find Notion app: Not installed")
        }

}

private fun buildServices(
        llmClient: LLMClient,
        includeCompleteTask: Boolean = false
): SessionServices {
        val toolRegistry = ToolRegistry()
        if (includeCompleteTask) {
                toolRegistry.register(CompleteTaskTool())
        }
        val policyEngine = PolicyEngine(appClassifier = AppClassifier(emptyMap()))
        val testCatalog =
                testModelCatalog(
                        """{"gpt-5.2":{"display_name":"GPT-5.2","model_id":"gpt-5.2"}}"""
                )
        return SessionServices(
                toolRegistry = toolRegistry,
                toolRouter = ToolRouter(toolRegistry, policyEngine),
                historyManager = HistoryManager(),
                sessionState = AgentSessionState(),
                policyEngine = policyEngine,
                appClassifier = AppClassifier(emptyMap()),
                platform = FakeAndroidPlatform(),
                config =
                        SessionConfig(
                                actionDelayMs = 0,
                                llm = SessionLlmConfig(baseUrl = "http://localhost:8000/v1")
                        ),
                llmClient = llmClient,
                modelCatalog = testCatalog,
                llmClientFactory = LLMClientFactory.forTest(testCatalog, llmClient),
                traceRecorder = NoopTraceRecorder,
                recordingService = io.mockk.mockk(relaxed = true)
        )
}

private class SubAgentTestLLMClient(private val delayMs: Long) : LLMClient() {
        override suspend fun chatWithTools(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String,
        maxOutputTokens: Long?,
        ): ResponsesResult {
                return ResponsesResult(
                        textContent = "done",
                        toolCalls = emptyList(),
                        responseId = "resp"
                )
        }

        override fun chatWithToolsStreaming(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String
        ): Flow<LLMStreamEvent> = flow {
                if (delayMs > 0) {
                        delay(delayMs)
                }
                emit(LLMStreamEvent.TextDelta("done"))
                emit(LLMStreamEvent.Completed)
        }
}

private class ScriptedSubAgentLLMClient(private val events: List<LLMStreamEvent>) : LLMClient() {
        override suspend fun chatWithTools(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String,
        maxOutputTokens: Long?,
        ): ResponsesResult {
                return ResponsesResult(
                        textContent = null,
                        toolCalls = emptyList(),
                        responseId = "resp"
                )
        }

        override fun chatWithToolsStreaming(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String
        ): Flow<LLMStreamEvent> = flow { events.forEach { emit(it) } }
}
