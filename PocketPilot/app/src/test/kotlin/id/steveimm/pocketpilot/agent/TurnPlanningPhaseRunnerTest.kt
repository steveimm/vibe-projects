package id.steveimm.pocketpilot.agent

import id.steveimm.pocketpilot.test.testModelCatalog

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.agent.cognition.policy.TurnToolPolicy
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.history.MessageKind
import id.steveimm.pocketpilot.history.ResponseItem
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.LLMStreamEvent
import id.steveimm.pocketpilot.llm.LLMToolCall
import id.steveimm.pocketpilot.llm.ResponsesResult
import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.protocol.AgentEvent
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionId
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
import id.steveimm.pocketpilot.protocol.StatusUpdate
import id.steveimm.pocketpilot.protocol.ThoughtUpdate
import id.steveimm.pocketpilot.session.AgentSessionState
import id.steveimm.pocketpilot.session.SessionServices
import id.steveimm.pocketpilot.test.FakeAndroidPlatform
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.PolicyEngine
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolRouter
import id.steveimm.pocketpilot.trace.AgentTrace
import id.steveimm.pocketpilot.trace.NoopTraceRecorder
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import org.json.JSONObject
import org.junit.Test

class TurnPlanningPhaseRunnerTest {

    @Test
    fun `planning phase writes screen observation to history before LLM call`() = runTest {
        val harness = PlanningHarness.build()
        harness.llmClient.historySnapshotProvider = {
            harness.services.historyManager.getAll()
        }

        harness.runner.runPlanningPhase(
            turnId = "turn-1",
            turnNumber = 1,
            snapshot = ScreenSnapshot(timestamp = 1L, elements = emptyList()),
            currentPackageName = null,
            warnings = emptyList()
        )

        val historyAtCall = harness.llmClient.historyAtCall
        assertThat(historyAtCall).isNotNull()
        val hasScreenObs = historyAtCall!!.any { item ->
            item is ResponseItem.Message && item.kind == MessageKind.SCREEN_OBSERVATION
        }
        assertThat(hasScreenObs).isTrue()
    }

    @Test
    fun `arbitration warning emitted when tools are dropped by policy`() = runTest {
        val harness = PlanningHarness.build(
            toolCalls = listOf(
                LLMToolCall(
                    callId = "call-action",
                    name = "mobile_action",
                    arguments = """{"action_type":"click","target_id":"1"}"""
                ),
                LLMToolCall(
                    callId = "call-complete",
                    name = "complete_task",
                    arguments = """{"status":"success","answer":"done"}"""
                )
            )
        )

        val output = harness.runner.runPlanningPhase(
            turnId = "turn-1",
            turnNumber = 1,
            snapshot = ScreenSnapshot(timestamp = 1L, elements = emptyList()),
            currentPackageName = null,
            warnings = emptyList()
        )

        assertThat(output.arbitration.droppedToolCalls.map { it.name })
            .containsExactly("complete_task")
        val statuses = harness.events.filterIsInstance<StatusUpdate>().map { it.status }
        assertThat(statuses.any { it.contains("Dropped 1 tool call") }).isTrue()
    }

    @Test
    fun `agent_thought event emitted during planning with LLM reasoning content`() = runTest {
        val harness = PlanningHarness.build(
            toolCalls = listOf(
                LLMToolCall(
                    callId = "call-1",
                    name = "mobile_action",
                    arguments = JSONObject()
                        .put("agent_thought", "Tapping settings icon")
                        .put("action_type", "click")
                        .toString()
                )
            )
        )

        harness.runner.runPlanningPhase(
            turnId = "turn-1",
            turnNumber = 1,
            snapshot = ScreenSnapshot(timestamp = 1L, elements = emptyList()),
            currentPackageName = null,
            warnings = emptyList()
        )

        val thoughts = harness.events.filterIsInstance<ThoughtUpdate>()
        assertThat(thoughts).hasSize(1)
        assertThat(thoughts[0].full).isEqualTo("Tapping settings icon")
    }

    @Test
    fun `model resolution selects correct model for planning phase`() = runTest {
        val catalogJson =
            """{"planner":{"display_name":"Planner","model_id":"planner-actual-id"}}"""
        val harness = PlanningHarness.build(
            catalogJson = catalogJson,
            modelName = "planner"
        )

        harness.runner.runPlanningPhase(
            turnId = "turn-1",
            turnNumber = 1,
            snapshot = ScreenSnapshot(timestamp = 1L, elements = emptyList()),
            currentPackageName = null,
            warnings = emptyList()
        )

        assertThat(harness.llmClient.lastModel).isEqualTo("planner-actual-id")
        assertThat(harness.llmClient.streamingCalls).isEqualTo(1)
    }
}

private class PlanningHarness(
    val runner: TurnPlanningPhaseRunner,
    val services: SessionServices,
    val llmClient: CapturingLLMClient,
    val events: CopyOnWriteArrayList<AgentEvent>
) {
    companion object {
        fun build(
            toolCalls: List<LLMToolCall> = emptyList(),
            textContent: String? = null,
            catalogJson: String =
                """{"gpt-5.2":{"display_name":"GPT-5.2","model_id":"gpt-5.2"}}""",
            modelName: String = "gpt-5.2"
        ): PlanningHarness {
            val events = CopyOnWriteArrayList<AgentEvent>()
            val llmClient = CapturingLLMClient(toolCalls = toolCalls, textContent = textContent)
            val catalog = testModelCatalog(catalogJson)
            val toolRegistry = ToolRegistry()
            val policyEngine = PolicyEngine(appClassifier = AppClassifier(emptyMap()))
            val services = SessionServices(
                toolRegistry = toolRegistry,
                toolRouter = ToolRouter(toolRegistry, policyEngine),
                historyManager = HistoryManager(),
                sessionState = AgentSessionState(),
                policyEngine = policyEngine,
                appClassifier = AppClassifier(emptyMap()),
                platform = FakeAndroidPlatform(),
                config = SessionConfig(
                    actionDelayMs = 0,
                    mainModel = modelName,
                    llm = SessionLlmConfig(baseUrl = "http://localhost:8000/v1")
                ),
                llmClient = llmClient,
                modelCatalog = catalog,
                llmClientFactory = LLMClientFactory.forTest(catalog, llmClient),
                traceRecorder = NoopTraceRecorder,
                recordingService = io.mockk.mockk(relaxed = true)
            )
            val sessionId = SessionId("session-planner")
            val dispatcher = AgentEventDispatcher(
                sessionId = sessionId,
                eventEmitter = { events.add(it) }
            )
            val trace = AgentTrace(sessionId = sessionId, services = services)
            val config = AgentExecutionConfig(
                goal = "goal",
                sessionId = sessionId,
                uiSettleDelayMs = 0,
                systemPrompt = "test prompt",
                modelName = modelName
            )
            val runner = TurnPlanningPhaseRunner(
                config = config,
                services = services,
                eventDispatcher = dispatcher,
                trace = trace,
                turnPolicyEngine = TurnToolPolicy()
            )
            return PlanningHarness(runner, services, llmClient, events)
        }
    }
}

private class CapturingLLMClient(
    private val toolCalls: List<LLMToolCall> = emptyList(),
    private val textContent: String? = null
) : LLMClient() {
    var lastModel: String? = null
    var historyAtCall: List<ResponseItem>? = null
    var streamingCalls: Int = 0
    var historySnapshotProvider: (() -> List<ResponseItem>)? = null

    override suspend fun chatWithTools(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String,
        maxOutputTokens: Long?,
    ): ResponsesResult =
        ResponsesResult(textContent = textContent, toolCalls = emptyList(), responseId = "noop")

    override fun chatWithToolsStreaming(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String
    ): Flow<LLMStreamEvent> = flow {
        lastModel = model
        historyAtCall = historySnapshotProvider?.invoke()
        streamingCalls += 1
        emit(LLMStreamEvent.Created("stream-1"))
        textContent?.let { emit(LLMStreamEvent.TextDelta(it)) }
        toolCalls.forEach { emit(LLMStreamEvent.ToolCallDone(it)) }
        emit(LLMStreamEvent.Completed)
    }
}
