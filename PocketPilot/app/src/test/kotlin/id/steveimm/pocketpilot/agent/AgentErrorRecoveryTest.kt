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
import id.steveimm.pocketpilot.session.SessionServices
import id.steveimm.pocketpilot.test.FakeAndroidPlatform
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.PolicyEngine
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolRouter
import id.steveimm.pocketpilot.trace.NoopTraceRecorder
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AgentErrorRecoveryTest {

        @Test
        fun `dns failure is non recoverable`() = runTest {
                val services =
                        buildServices(
                                AgentErrorTestLLMClient(
                                        UnknownHostException("Unable to resolve host")
                                )
                        )
                val agent =
                        Agent(
                                config =
                                        AgentExecutionConfig(
                                                goal = "goal",
                                                sessionId = SessionId.generate(),
                                                uiSettleDelayMs = 0,
                                                systemPrompt = "test prompt"
                                        ),
                                services = services,
                                compactor = noopCompactor(),
                                eventEmitter = {},
                                cancellationSignal = CompletableDeferred()
                        )

                val result = agent.run()

                assertThat(result).isInstanceOf(AgentStopReason.Error::class.java)
        }

        @Test
        fun `transient network error stops with error when no retry budget remains`() = runTest {
                val services =
                        buildServices(AgentErrorTestLLMClient(SocketTimeoutException("timeout")))
                val agent =
                        Agent(
                                config =
                                        AgentExecutionConfig(
                                                goal = "goal",
                                                sessionId = SessionId.generate(),
                                                uiSettleDelayMs = 0,
                                                systemPrompt = "test prompt"
                                        ),
                                services = services,
                                compactor = noopCompactor(),
                                eventEmitter = {},
                                cancellationSignal = CompletableDeferred()
                        )

                val result = agent.run()

                assertThat(result).isInstanceOf(AgentStopReason.Error::class.java)
        }

        @Test
        fun `context length exceeded is non recoverable`() = runTest {
                val services =
                        buildServices(
                                AgentErrorTestLLMClient(
                                        RuntimeException("maximum context length exceeded")
                                )
                        )
                val agent =
                        Agent(
                                config =
                                        AgentExecutionConfig(
                                                goal = "goal",
                                                sessionId = SessionId.generate(),
                                                uiSettleDelayMs = 0,
                                                systemPrompt = "test prompt"
                                        ),
                                services = services,
                                compactor = noopCompactor(),
                                eventEmitter = {},
                                cancellationSignal = CompletableDeferred()
                        )

                val result = agent.run()

                assertThat(result).isInstanceOf(AgentStopReason.Error::class.java)
        }
}

private fun buildServices(llmClient: LLMClient): SessionServices {
        val toolRegistry = ToolRegistry()
        val policyEngine = PolicyEngine(appClassifier = AppClassifier(emptyMap()))
        val toolRouter = ToolRouter(toolRegistry, policyEngine)
        val platform = FakeAndroidPlatform()
        val config =
                SessionConfig(
                        actionDelayMs = 0,
                        llm = SessionLlmConfig(backendType = LLMBackendType.OPENAI)
                )
        val testCatalog =
                ModelCatalog.fromJson(
                        """{"gpt-5.2":{"display_name":"GPT-5.2","provider":"OPENAI_API","api":"response","model_id":"gpt-5.2"}}"""
                )
        return SessionServices(
                toolRegistry = toolRegistry,
                toolRouter = toolRouter,
                historyManager = HistoryManager(),
                sessionState = id.steveimm.pocketpilot.session.AgentSessionState(),
                policyEngine = policyEngine,
                appClassifier = AppClassifier(emptyMap()),
                platform = platform,
                config = config,
                llmClient = llmClient,
                modelCatalog = testCatalog,
                llmClientFactory = LLMClientFactory.forTest(testCatalog, llmClient),
                traceRecorder = NoopTraceRecorder,
                recordingService = io.mockk.mockk(relaxed = true)
        )
}

private class AgentErrorTestLLMClient(private val throwable: Throwable) : LLMClient() {
        override suspend fun chatWithTools(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String,
        maxOutputTokens: Long?,
        ): ResponsesResult {
                throw throwable
        }

        override fun chatWithToolsStreaming(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String
        ): Flow<LLMStreamEvent> = flow { throw throwable }
}
