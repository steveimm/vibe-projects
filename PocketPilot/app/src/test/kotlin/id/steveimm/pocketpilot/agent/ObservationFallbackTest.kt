package id.steveimm.pocketpilot.agent

import id.steveimm.pocketpilot.test.testModelCatalog

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.platform.ActionResult
import id.steveimm.pocketpilot.platform.AndroidPlatform
import id.steveimm.pocketpilot.platform.AppInfo
import id.steveimm.pocketpilot.platform.DisplayInfo
import id.steveimm.pocketpilot.platform.UIAction
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionId
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
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

/** Regression coverage for er-harden-cleanup: when captureObservationWithSnapshot() throws (e.g. platform.captureScreen fails), the
 * tool is still marked executed and execution continues without propagating the exception. */
class ObservationFallbackTest {

    @Test
    fun `screen capture failure falls back to text observation and marks tool executed`() = runTest {
        val platform = ThrowingCapturePlatform()
        val tool = NoObservationTool()
        val registry = ToolRegistry().apply { register(tool) }
        val policyEngine = PolicyEngine(appClassifier = AppClassifier(emptyMap())).apply {
            setApprovalMode(ApprovalMode.AUTO_APPROVE)
        }
        val catalog = testModelCatalog(
            """{"gpt-5.2":{"display_name":"GPT-5.2","model_id":"gpt-5.2"}}"""
        )
        val sessionConfig = SessionConfig(
            actionDelayMs = 0,
            llm = SessionLlmConfig(baseUrl = "http://localhost:8000/v1")
        )
        val services = SessionServices(
            toolRegistry = registry,
            toolRouter = ToolRouter(registry, policyEngine),
            historyManager = HistoryManager(),
            policyEngine = policyEngine,
            appClassifier = AppClassifier(emptyMap()),
            platform = platform,
            config = sessionConfig,
            llmClient = mockk(relaxed = true),
            modelCatalog = catalog,
            llmClientFactory = LLMClientFactory(catalog = catalog, credentialStore = null),
            traceRecorder = NoopTraceRecorder,
            recordingService = mockk(relaxed = true)
        )
        val sessionId = SessionId.generate()
        val trace = AgentTrace(sessionId, services)
        val dispatcher = AgentEventDispatcher(sessionId) { /* noop */ }
        val execConfig = AgentExecutionConfig(
            goal = "goal",
            sessionId = sessionId,
            uiSettleDelayMs = 0,
            systemPrompt = "p"
        )
        val runner = TurnExecutionPhaseRunner(execConfig, services, dispatcher, trace)

        val toolCall = ToolCallRequest(
            id = "call-1",
            name = tool.name,
            arguments = JSONObject()
        )
        val initialSnapshot = ScreenSnapshot(timestamp = 0L, elements = emptyList())

        val result = runner.executeActions(
            turnId = "turn-1",
            turnNumber = 0,
            initialSnapshot = initialSnapshot,
            toolCallsToExecute = listOf(toolCall)
        )

        assertThat(result.executedToolIds).containsExactly("call-1")
        assertThat(result.terminatedEarly).isFalse()
        assertThat(result.lastTerminalResult).isInstanceOf(ToolCallResult.Success::class.java)
        assertThat(platform.captureAttempts).isEqualTo(1)
    }
}

private class ThrowingCapturePlatform : AndroidPlatform {
    override val mode: id.steveimm.pocketpilot.protocol.PlatformMode = id.steveimm.pocketpilot.protocol.PlatformMode.ACCESSIBILITY
    var captureAttempts: Int = 0
    override suspend fun captureScreen(): ScreenSnapshot {
        captureAttempts++
        throw RuntimeException("capture failed")
    }
    override suspend fun performAction(action: UIAction): ActionResult = ActionResult.Success()
    override fun hasRequiredPermissions(): Boolean = true
    override fun getCurrentPackageName(): String? = "com.example.fake"
    override fun getDisplayInfo(): DisplayInfo =
        DisplayInfo(widthPixels = 1080, heightPixels = 1920, density = 2f)
    override suspend fun getInstalledApps(): List<AppInfo> = emptyList()
    override suspend fun launchApp(packageName: String): ActionResult = ActionResult.Success()
}

private class NoObservationTool : ToolSpec {
    override val name: String = "test_fallback_tool"
    override val description: String = "test tool returning Success with no observation"
    override val parameterSchema: JSONObject = JSONObject().apply {
        put("type", "object")
        put("properties", JSONObject())
        put("additionalProperties", false)
    }

    override fun validate(params: JSONObject): ValidationResult = ValidationResult.Valid

    override fun createInvocation(params: JSONObject): ToolInvocation = object : ToolInvocation {
        override val toolName: String = name
        override val params: JSONObject = params
        override fun getDescription(): String = "test"
        override suspend fun execute(context: ToolExecutionContext): ToolExecutionResult =
            ToolExecutionResult.Success(output = "ok", observation = null)
    }
}
