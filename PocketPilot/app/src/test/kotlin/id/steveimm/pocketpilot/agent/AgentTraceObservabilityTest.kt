package id.steveimm.pocketpilot.agent

import id.steveimm.pocketpilot.test.testModelCatalog

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.LLMStreamEvent
import id.steveimm.pocketpilot.llm.ResponsesResult
import id.steveimm.pocketpilot.model.ScreenSnapshot
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
import id.steveimm.pocketpilot.trace.AgentTrace
import id.steveimm.pocketpilot.trace.TraceArtifactRef
import id.steveimm.pocketpilot.trace.TraceEventRecord
import id.steveimm.pocketpilot.trace.TraceRecorder
import com.openai.models.responses.EasyInputMessage
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Test

class AgentTraceObservabilityTest {

        @Test
        fun `llm request stores full prompt and input items artifacts with redaction`() = runTest {
                val recorder = RecordingTraceRecorder()
                val trace =
                        AgentTrace(
                                sessionId = SessionId("session-1"),
                                services = buildServices(recorder)
                        )
                val inputItems =
                        listOf(
                                ResponseInputItem.ofEasyInputMessage(
                                        EasyInputMessage.builder()
                                                .role(EasyInputMessage.Role.USER)
                                                .content(
                                                        "email me at user@example.com with token sk_live_ABC12345678901234567890"
                                                )
                                                .build()
                                )
                        )

                trace.sessionStarted(
                        AgentExecutionConfig(
                                goal = "test",
                                sessionId = SessionId("session-1"),
                                systemPrompt = "test prompt",
                                modelName = "local-model"
                        )
                )
                trace.llmRequest(
                        turnId = "turn-1",
                        turnNumber = 1,
                        snapshot = ScreenSnapshot(timestamp = 1L, elements = emptyList()),
                        systemPrompt = "Bearer abcdefghijklmnopqrstuvwxyz123456 user@example.com",
                        userContextText = "Authorization: token=abcdefghijklmnop1234567890",
                        history = emptyList(),
                        inputItems = inputItems,
                        modelName = "local-model",
                        modelId = "local-model"
                )
                trace.sessionStopped(AgentStopReason.GoalAchieved(), turnsExecuted = 1)

                val sessionStarted = recorder.findEvent("session_started")
                assertThat(sessionStarted).isNotNull()
                val dataJson = Json.parseToJsonElement(sessionStarted!!.data.toString()).jsonObject
                assertThat(dataJson["agent_role"]?.jsonPrimitive?.content).isEqualTo("main")
                assertThat(dataJson["agent_id"]?.jsonPrimitive?.content).isEqualTo("session-1")
                assertThat(dataJson["model"]?.jsonPrimitive?.content).isEqualTo("local-model")
                assertThat(dataJson["main_model"]?.jsonPrimitive?.content).isEqualTo("local-model")

                val fullPrompt = recorder.findStored("turn_1_full_prompt.txt")
                val inputItemsJson = recorder.findStored("turn_1_llm_input_items.json")
                val runSummary = recorder.findStored("run_summary.json")

                assertThat(fullPrompt).isNotNull()
                assertThat(inputItemsJson).isNotNull()
                assertThat(runSummary).isNotNull()

                assertThat(fullPrompt).doesNotContain("user@example.com")
                assertThat(fullPrompt).contains("[REDACTED_EMAIL]")
                assertThat(fullPrompt).doesNotContain("abcdefghijklmnopqrstuvwxyz123456")
                assertThat(fullPrompt).contains("[REDACTED_TOKEN]")

                assertThat(inputItemsJson).contains("\"type\":\"message\"")
                assertThat(inputItemsJson).contains("[REDACTED_EMAIL]")
                assertThat(inputItemsJson).contains("[REDACTED_TOKEN]")
        }
}

private fun buildServices(traceRecorder: TraceRecorder): SessionServices {
        val toolRegistry = ToolRegistry()
        val policyEngine = PolicyEngine(appClassifier = AppClassifier(emptyMap()))
        val toolRouter = ToolRouter(toolRegistry, policyEngine)
        val platform = FakeAndroidPlatform()
        val config =
                SessionConfig(
                        actionDelayMs = 0,
                        mainModel = "local-model",
                        llm = SessionLlmConfig(baseUrl = "http://localhost:8000/v1")
                )
        val testCatalog =
                testModelCatalog(
                        """{"local-model":{"display_name":"GPT-5.2","model_id":"local-model"}}"""
                )
        val noopClient = NoopLLMClient()
        return SessionServices(
                toolRegistry = toolRegistry,
                toolRouter = toolRouter,
                historyManager = HistoryManager(),
                sessionState = AgentSessionState(),
                policyEngine = policyEngine,
                appClassifier = AppClassifier(emptyMap()),
                platform = platform,
                config = config,
                llmClient = noopClient,
                modelCatalog = testCatalog,
                llmClientFactory = LLMClientFactory.forTest(testCatalog, noopClient),
                traceRecorder = traceRecorder,
                recordingService = io.mockk.mockk(relaxed = true)
        )
}

private class RecordingTraceRecorder : TraceRecorder {
        override val enabled: Boolean = true
        override val runId: String = "run-test"

        private val seq = AtomicLong(0L)
        private val storedTexts = mutableMapOf<String, String>()
        private val recordedEvents = mutableListOf<TraceEventRecord>()

        override fun nextSeq(): Long = seq.incrementAndGet()

        override fun record(event: TraceEventRecord) {
                recordedEvents.add(event)
        }

        override fun storeText(
                kind: String,
                filenameHint: String,
                content: String,
                mimeType: String?,
                description: String?
        ): TraceArtifactRef {
                storedTexts[filenameHint] = content
                return TraceArtifactRef(
                        kind = kind,
                        path = "artifacts/$filenameHint",
                        mimeType = mimeType,
                        description = description
                )
        }

        override fun storeBytes(
                kind: String,
                filenameHint: String,
                bytes: ByteArray,
                mimeType: String?,
                description: String?
        ): TraceArtifactRef {
                return TraceArtifactRef(
                        kind = kind,
                        path = "artifacts/$filenameHint",
                        mimeType = mimeType,
                        description = description
                )
        }

        override suspend fun flush() = Unit

        override suspend fun close() = Unit

        fun findStored(filenameHint: String): String? = storedTexts[filenameHint]

        fun findEvent(type: String): TraceEventRecord? {
                return recordedEvents.firstOrNull { it.type == type }
        }
}

private class NoopLLMClient : LLMClient() {
        override suspend fun chatWithTools(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String,
        maxOutputTokens: Long?,
        ): ResponsesResult {
                return ResponsesResult(
                        textContent = "",
                        toolCalls = emptyList(),
                        responseId = "noop"
                )
        }

        override fun chatWithToolsStreaming(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String
        ): Flow<LLMStreamEvent> = emptyFlow()
}
