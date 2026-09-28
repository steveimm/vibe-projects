package id.steveimm.pocketpilot.agent

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.history.ResponseItem
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.ModelCatalog
import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.platform.ActionResult
import id.steveimm.pocketpilot.platform.AndroidPlatform
import id.steveimm.pocketpilot.platform.AppInfo
import id.steveimm.pocketpilot.platform.DisplayInfo
import id.steveimm.pocketpilot.platform.UIAction
import id.steveimm.pocketpilot.protocol.ActionExecuted
import id.steveimm.pocketpilot.protocol.ActionOutcome
import id.steveimm.pocketpilot.protocol.AgentEvent
import id.steveimm.pocketpilot.protocol.ApprovalDecision
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.ApprovalRequired
import id.steveimm.pocketpilot.protocol.LLMBackendType
import id.steveimm.pocketpilot.protocol.ScreenCaptured
import id.steveimm.pocketpilot.protocol.ScreenStatePhase
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionId
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
import id.steveimm.pocketpilot.session.AgentSessionState
import id.steveimm.pocketpilot.session.SessionServices
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.PolicyEngine
import id.steveimm.pocketpilot.tool.ToolCallResult
import id.steveimm.pocketpilot.tool.ToolExecutionContext
import id.steveimm.pocketpilot.tool.ToolExecutionResult
import id.steveimm.pocketpilot.tool.ToolInvocation
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolRouter
import id.steveimm.pocketpilot.tool.ToolSpec
import id.steveimm.pocketpilot.tool.ValidationResult
import id.steveimm.pocketpilot.trace.AgentTrace
import id.steveimm.pocketpilot.trace.NoopTraceRecorder
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.json.JSONObject
import org.junit.Test

/** Tests for [TurnExecutionPhaseRunner.executeActions] — the tool execution seam. */
class TurnExecutionPhaseRunnerTest {

    @Test
    fun `successful tool execution appends function call and output to history`() = runTest {
        val platform = FakePlatform()
        val tool = StubTool(name = "stub_tool", result = ToolExecutionResult.Success(output = "ran-ok"))
        val harness = TestHarness.build(platform, listOf(tool))

        val result = harness.runner.executeActions(
            turnId = "t-1",
            turnNumber = 0,
            initialSnapshot = ScreenSnapshot(timestamp = 0L, elements = emptyList()),
            toolCallsToExecute = listOf(ToolCallRequest("call-1", tool.name, JSONObject()))
        )

        assertThat(result.executedToolIds).containsExactly("call-1")
        assertThat(result.terminatedEarly).isFalse()

        val items = harness.services.historyManager.getAll()
        val call = items.filterIsInstance<ResponseItem.FunctionCall>().single()
        val output = items.filterIsInstance<ResponseItem.FunctionCallOutput>().single()
        assertThat(call.id).isEqualTo("call-1")
        assertThat(call.name).isEqualTo("stub_tool")
        assertThat(output.callId).isEqualTo("call-1")
        assertThat(output.success).isTrue()
        assertThat(output.content).contains("ran-ok")
    }

    @Test
    fun `approval event is emitted before action executed for policy-gated tool`() = runTest {
        val platform = FakePlatform()
        val tool = StubTool(name = "gated_tool", result = ToolExecutionResult.Success(output = "done"))
        // Default AppClassifier treats all packages as CAUTIOUS.
        // Unknown tool names are isScreenChanging=true → SMART+CAUTIOUS triggers AskUser.
        val harness = TestHarness.build(
            platform = platform,
            tools = listOf(tool),
            approvalMode = ApprovalMode.SMART
        )
        // Resolve approval as soon as the ApprovalRequired event is emitted.
        harness.setApprovalAutoResponder(ApprovalDecision.APPROVED)

        harness.runner.executeActions(
            turnId = "t-1",
            turnNumber = 0,
            initialSnapshot = ScreenSnapshot(timestamp = 0L, elements = emptyList()),
            toolCallsToExecute = listOf(ToolCallRequest("call-1", tool.name, JSONObject()))
        )

        val names = harness.events.map { it::class.simpleName }
        val approvalIdx = names.indexOf("ApprovalRequired")
        val executedIdx = names.indexOf("ActionExecuted")
        assertThat(approvalIdx).isAtLeast(0)
        assertThat(executedIdx).isAtLeast(0)
        assertThat(approvalIdx).isLessThan(executedIdx)
        assertThat(tool.executionCount).isEqualTo(1)

        val approval = harness.events.filterIsInstance<ApprovalRequired>().single()
        assertThat(approval.details.callId).isEqualTo("call-1")
        val executed = harness.events.filterIsInstance<ActionExecuted>().single()
        assertThat(executed.outcome).isEqualTo(ActionOutcome.SUCCESS)
    }

    @Test
    fun `execution aborts remaining tools after first failure`() = runTest {
        val platform = FakePlatform()
        val first = StubTool(name = "first_tool", result = ToolExecutionResult.Failure("boom"))
        val second = StubTool(name = "second_tool", result = ToolExecutionResult.Success(output = "ok"))
        val harness = TestHarness.build(platform, listOf(first, second))

        val result = harness.runner.executeActions(
            turnId = "t-1",
            turnNumber = 0,
            initialSnapshot = ScreenSnapshot(timestamp = 0L, elements = emptyList()),
            toolCallsToExecute = listOf(
                ToolCallRequest("call-1", first.name, JSONObject()),
                ToolCallRequest("call-2", second.name, JSONObject())
            )
        )

        assertThat(result.terminatedEarly).isTrue()
        assertThat(result.executedToolIds).containsExactly("call-1")
        assertThat(result.lastTerminalResult).isInstanceOf(ToolCallResult.Error::class.java)
        assertThat(first.executionCount).isEqualTo(1)
        assertThat(second.executionCount).isEqualTo(0)
    }

    @Test
    fun `post-action screen capture emits POST_ACTION screen event`() = runTest {
        val platform = FakePlatform()
        // Tool returns no observation → runner falls through to captureObservationWithSnapshot.
        val tool = StubTool(
            name = "no_obs_tool",
            result = ToolExecutionResult.Success(output = "ok", observation = null)
        )
        val harness = TestHarness.build(platform, listOf(tool))

        harness.runner.executeActions(
            turnId = "t-1",
            turnNumber = 3,
            initialSnapshot = ScreenSnapshot(timestamp = 0L, elements = emptyList()),
            toolCallsToExecute = listOf(ToolCallRequest("call-1", tool.name, JSONObject()))
        )

        assertThat(platform.captureCount).isEqualTo(1)
        val capture = harness.events.filterIsInstance<ScreenCaptured>().single()
        assertThat(capture.phase).isEqualTo(ScreenStatePhase.POST_ACTION)
        assertThat(capture.turnId).isEqualTo("t-1")
        assertThat(capture.turnNumber).isEqualTo(3)
    }
}

private class TestHarness(
    val runner: TurnExecutionPhaseRunner,
    val services: SessionServices,
    val events: MutableList<AgentEvent>,
    private val setResponder: (ApprovalDecision) -> Unit
) {
    fun setApprovalAutoResponder(decision: ApprovalDecision) = setResponder(decision)

    companion object {
        fun build(
            platform: AndroidPlatform,
            tools: List<ToolSpec>,
            approvalMode: ApprovalMode = ApprovalMode.AUTO_APPROVE
        ): TestHarness {
            val registry = ToolRegistry().apply { tools.forEach { register(it) } }
            val policyEngine = PolicyEngine(appClassifier = AppClassifier(emptyMap())).apply {
                setApprovalMode(approvalMode)
            }
            val toolRouter = ToolRouter(registry, policyEngine)
            val catalog = ModelCatalog.fromJson(
                """{"gpt-5.2":{"display_name":"GPT-5.2","provider":"OPENAI_API","api":"response","model_id":"gpt-5.2"}}"""
            )
            val sessionConfig = SessionConfig(
                actionDelayMs = 0,
                llm = SessionLlmConfig(backendType = LLMBackendType.OPENAI)
            )
            val services = SessionServices(
                toolRegistry = registry,
                toolRouter = toolRouter,
                historyManager = HistoryManager(),
                sessionState = AgentSessionState(),
                policyEngine = policyEngine,
                appClassifier = AppClassifier(emptyMap()),
                platform = platform,
                config = sessionConfig,
                llmClient = mockk(relaxed = true),
                modelCatalog = catalog,
                llmClientFactory = LLMClientFactory(catalog = catalog, authStore = null),
                traceRecorder = NoopTraceRecorder,
                recordingService = mockk(relaxed = true)
            )
            val sessionId = SessionId.generate()
            val trace = AgentTrace(sessionId, services)
            val events = mutableListOf<AgentEvent>()
            var autoApproval: ApprovalDecision? = null
            val dispatcher = AgentEventDispatcher(sessionId) { event ->
                events += event
                if (event is ApprovalRequired) {
                    autoApproval?.let { toolRouter.resolveApproval(event.details.callId, it) }
                }
            }
            val execConfig = AgentExecutionConfig(
                goal = "goal",
                sessionId = sessionId,
                uiSettleDelayMs = 0,
                systemPrompt = "p"
            )
            val runner = TurnExecutionPhaseRunner(execConfig, services, dispatcher, trace)
            return TestHarness(runner, services, events) { autoApproval = it }
        }
    }
}

private class FakePlatform : AndroidPlatform {
    override val mode: id.steveimm.pocketpilot.protocol.PlatformMode = id.steveimm.pocketpilot.protocol.PlatformMode.ACCESSIBILITY
    var captureCount: Int = 0
    override suspend fun captureScreen(): ScreenSnapshot {
        captureCount++
        return ScreenSnapshot(timestamp = captureCount.toLong(), elements = emptyList())
    }
    override suspend fun performAction(action: UIAction): ActionResult = ActionResult.Success()
    override fun hasRequiredPermissions(): Boolean = true
    override fun getCurrentPackageName(): String? = "com.example.fake"
    override fun getDisplayInfo(): DisplayInfo =
        DisplayInfo(widthPixels = 1080, heightPixels = 1920, density = 2f)
    override suspend fun getInstalledApps(): List<AppInfo> = emptyList()
    override suspend fun launchApp(packageName: String): ActionResult = ActionResult.Success()
}

private class StubTool(
    override val name: String,
    private val result: ToolExecutionResult
) : ToolSpec {
    var executionCount: Int = 0
        private set
    override val description: String = "stub"
    override val parameterSchema: JSONObject = JSONObject().apply {
        put("type", "object")
        put("properties", JSONObject())
        put("additionalProperties", false)
    }

    override fun validate(params: JSONObject): ValidationResult = ValidationResult.Valid

    override fun createInvocation(params: JSONObject): ToolInvocation = object : ToolInvocation {
        override val toolName: String = name
        override val params: JSONObject = params
        override fun getDescription(): String = "stub $name"
        override suspend fun execute(context: ToolExecutionContext): ToolExecutionResult {
            executionCount++
            return result
        }
    }
}
