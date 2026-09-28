package id.steveimm.pocketpilot.agent

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.LLMStreamEvent
import id.steveimm.pocketpilot.llm.ModelCatalog
import id.steveimm.pocketpilot.llm.ResponsesResult
import id.steveimm.pocketpilot.protocol.LLMBackendType
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
import id.steveimm.pocketpilot.trace.NoopTraceRecorder
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import org.junit.Test

class LocalBackendTurnRoutingTest {

        @Test
        fun `local backend uses local llm client without cloud api keys`() = runTest {
                val localClient = LocalBackendTestLLMClient()
                val catalog =
                        ModelCatalog.fromJson(
                                """{"gpt-5.2":{"display_name":"GPT-5.2","provider":"OPENAI_API","api":"response","model_id":"gpt-5.2"}}"""
                        )

                val sessionConfig =
                        SessionConfig(
                                llm = SessionLlmConfig(backendType = LLMBackendType.LOCAL),
                                actionDelayMs = 0
                        )
                val toolRegistry = ToolRegistry()
                val policyEngine = PolicyEngine(appClassifier = AppClassifier(emptyMap()))
                val services =
                        SessionServices(
                                toolRegistry = toolRegistry,
                                toolRouter = ToolRouter(toolRegistry, policyEngine),
                                historyManager = HistoryManager(),
                                sessionState = AgentSessionState(),
                                policyEngine = policyEngine,
                                appClassifier = AppClassifier(emptyMap()),
                                platform = FakeAndroidPlatform(),
                                config = sessionConfig,
                                llmClient = localClient,
                                modelCatalog = catalog,
                                llmClientFactory =
                                        LLMClientFactory(
                                                catalog = catalog,
                                                authStore = null
                                        ),
                                traceRecorder = NoopTraceRecorder,
                                recordingService = io.mockk.mockk(relaxed = true)
                        )

                val agent =
                        Agent(
                                config =
                                        AgentExecutionConfig(
                                                goal = "Say done",
                                                sessionId = SessionId("local-routing-test"),
                                                uiSettleDelayMs = 0,
                                                systemPrompt = "You are a test agent.",
                                                modelName = "gpt-5.2"
                                        ),
                                services = services,
                                compactor = noopCompactor(),
                                eventEmitter = {},
                                cancellationSignal = CompletableDeferred()
                        )

                val stopReason = agent.run()
                assertThat(stopReason).isInstanceOf(AgentStopReason.GoalAchieved::class.java)
                assertThat((stopReason as AgentStopReason.GoalAchieved).message).isEqualTo("done")
                assertThat(localClient.streamingCalls).isEqualTo(1)
        }
}

private class LocalBackendTestLLMClient : LLMClient() {
        var streamingCalls: Int = 0

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
                        responseId = "local"
                )
        }

        override fun chatWithToolsStreaming(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String
        ): Flow<LLMStreamEvent> = flow {
                streamingCalls += 1
                emit(LLMStreamEvent.Created("local"))
                emit(LLMStreamEvent.TextDelta("done"))
                emit(LLMStreamEvent.Completed)
        }
}
