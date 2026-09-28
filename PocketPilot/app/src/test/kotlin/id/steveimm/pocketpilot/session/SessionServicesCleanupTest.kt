package id.steveimm.pocketpilot.session

import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.ModelCatalog
import id.steveimm.pocketpilot.browser.cdp.CdpConnection
import id.steveimm.pocketpilot.browser.cdp.CdpConnectionClosedException
import id.steveimm.pocketpilot.browser.cdp.CdpConnectionFactory
import id.steveimm.pocketpilot.browser.cdp.shizuku.DevtoolsVersion
import id.steveimm.pocketpilot.browser.cdp.shizuku.PageTarget
import id.steveimm.pocketpilot.browser.script.BrowserDevtoolsBridge
import id.steveimm.pocketpilot.browser.script.BrowserScriptExecutor
import id.steveimm.pocketpilot.browser.script.BrowserSessionManager
import id.steveimm.pocketpilot.browser.script.ScriptResult
import id.steveimm.pocketpilot.protocol.LLMBackendType
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
import id.steveimm.pocketpilot.test.FakeAndroidPlatform
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.PolicyEngine
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolRouter
import id.steveimm.pocketpilot.trace.NoopTraceRecorder
import id.steveimm.pocketpilot.trace.TraceRecorder
import com.google.common.truth.Truth.assertThat
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import id.steveimm.pocketpilot.llm.LLMStreamEvent
import id.steveimm.pocketpilot.llm.ResponsesResult
import id.steveimm.pocketpilot.test.buildTestContext
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import io.mockk.every
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.junit.Test

class SessionServicesCleanupTest {

    @Test
    fun `cleanup continues after llmClient failure`() = runBlocking {
        val throwingClient = object : LLMClient() {
            var cleanupCalled = false
            override suspend fun chatWithTools(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String,
        maxOutputTokens: Long?,
            ): ResponsesResult = error("unused")

            override fun chatWithToolsStreaming(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String
            ): Flow<LLMStreamEvent> = flow { error("unused") }

            override suspend fun cleanup() {
                cleanupCalled = true
                throw RuntimeException("boom")
            }
        }

        val traceRecorder = mockk<TraceRecorder>(relaxed = true)
        val factory = mockk<LLMClientFactory>(relaxed = true)
        coEvery { factory.cleanupAll() } returns Unit

        val services = buildServices(throwingClient, factory, traceRecorder)

        val result = services.cleanup()

        assert(throwingClient.cleanupCalled) { "llmClient.cleanup must be invoked" }
        coVerify { factory.cleanupAll() }
        coVerify { traceRecorder.close() }
        check(result is CleanupResult.PartialFailure) { "expected PartialFailure, got $result" }
        assert(result.failures.any { it.step == "llmClient.cleanup" }) { "missing llmClient failure: ${result.failures}" }
    }

    @Test
    fun `cleanup closes trace even if factory cleanup throws`() = runBlocking {
        val factory = mockk<LLMClientFactory>(relaxed = true)
        coEvery { factory.cleanupAll() } throws RuntimeException("factory fail")
        val traceRecorder = mockk<TraceRecorder>(relaxed = true)

        val services = buildServices(object : LLMClient() {
            override suspend fun chatWithTools(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String,
        maxOutputTokens: Long?,
            ): ResponsesResult = error("unused")

            override fun chatWithToolsStreaming(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String
            ): Flow<LLMStreamEvent> = flow { error("unused") }
        }, factory, traceRecorder)

        services.cleanup()

        coVerify { traceRecorder.close() }
    }

    @Test
    fun `cleanup returns Success when all steps succeed`() = runBlocking {
        val factory = mockk<LLMClientFactory>(relaxed = true)
        coEvery { factory.cleanupAll() } returns Unit
        val traceRecorder = mockk<TraceRecorder>(relaxed = true)
        val client = object : LLMClient() {
            override suspend fun chatWithTools(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String,
        maxOutputTokens: Long?,
            ): ResponsesResult = error("unused")

            override fun chatWithToolsStreaming(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String
            ): Flow<LLMStreamEvent> = flow { error("unused") }
        }

        val result = buildServices(client, factory, traceRecorder).cleanup()

        check(result is CleanupResult.Success) { "expected Success, got $result" }
    }

    @Test
    fun `cleanup closes browser session manager`() = runBlocking {
        val bridge = FakeBrowserBridge()
        val connectionFactory = FakeCdpConnectionFactory()
        val context = buildTestContext(java.io.File("/tmp/session-browser-cleanup")).also {
            every { it.applicationContext } returns it
        }
        val scope = CoroutineScope(SupervisorJob())
        val manager = BrowserSessionManager(
            context = context,
            sessionScope = scope,
            traceRecorder = NoopTraceRecorder,
            bridgeFactory = { bridge },
            cdpConnectionFactory = connectionFactory,
            runnerFactory = { _, _, _ ->
                BrowserScriptExecutor { _, _ -> ScriptResult.Ok("\"ok\"") }
            },
        )
        val runResult = manager.run("return 1", 1_000)
        check(runResult is ScriptResult.Ok) { "expected fake browser_script success, got $runResult" }

        val factory = mockk<LLMClientFactory>(relaxed = true)
        coEvery { factory.cleanupAll() } returns Unit
        val services = buildServices(
            llmClient = object : LLMClient() {
                override suspend fun chatWithTools(
                    systemPrompt: String,
                    inputItems: List<ResponseInputItem>,
                    tools: List<FunctionTool>,
                    model: String,
        maxOutputTokens: Long?,
                ): ResponsesResult = error("unused")

                override fun chatWithToolsStreaming(
                    systemPrompt: String,
                    inputItems: List<ResponseInputItem>,
                    tools: List<FunctionTool>,
                    model: String
                ): Flow<LLMStreamEvent> = flow { error("unused") }
            },
            factory = factory,
            trace = mockk(relaxed = true),
            browserSessionManager = manager
        )

        services.cleanup()

        assert(bridge.closeCalls == 1) { "expected browser bridge close once, got ${bridge.closeCalls}" }
        assert(connectionFactory.connections.single().closeCalls == 1) {
            "expected CDP connection close once, got ${connectionFactory.connections.single().closeCalls}"
        }
    }

    @Test
    fun `cleanup still closes resources when cancelling tools and clearing history fail`() = runBlocking {
        val router = mockk<ToolRouter>(relaxed = true)
        every { router.cancelAll() } throws IllegalStateException("cancel failed")
        val history = mockk<HistoryManager>(relaxed = true)
        every { history.clear() } throws IllegalStateException("history failed")
        val client = mockk<LLMClient>(relaxed = true)
        val factory = mockk<LLMClientFactory>(relaxed = true)
        val trace = mockk<TraceRecorder>(relaxed = true)
        val services = buildServices(client, factory, trace).copy(toolRouter = router, historyManager = history)

        val result = services.cleanup()

        assertThat(result).isInstanceOf(CleanupResult.PartialFailure::class.java)
        val failures = (result as CleanupResult.PartialFailure).failures
        assertThat(failures.map { it.step }).containsExactly("toolRouter.cancelAll", "historyManager.clear").inOrder()
        coVerify { client.cleanup() }
        coVerify { factory.cleanupAll() }
        coVerify { trace.close() }
    }

    private fun buildServices(
        llmClient: LLMClient,
        factory: LLMClientFactory,
        trace: TraceRecorder,
        browserSessionManager: BrowserSessionManager? = null
    ): SessionServices {
        val toolRegistry = ToolRegistry()
        val policyEngine = PolicyEngine(appClassifier = AppClassifier(emptyMap()))
        val toolRouter = ToolRouter(toolRegistry, policyEngine)
        val catalog =
            ModelCatalog.fromJson(
                """{"gpt-5.2":{"display_name":"GPT-5.2","provider":"OPENAI_API","api":"response","model_id":"gpt-5.2"}}"""
            )
        return SessionServices(
            toolRegistry = toolRegistry,
            toolRouter = toolRouter,
            historyManager = HistoryManager(),
            sessionState = AgentSessionState(),
            policyEngine = policyEngine,
            appClassifier = AppClassifier(emptyMap()),
            platform = FakeAndroidPlatform(),
            config = SessionConfig(
                actionDelayMs = 0,
                llm = SessionLlmConfig(backendType = LLMBackendType.OPENAI)
            ),
            llmClient = llmClient,
            modelCatalog = catalog,
            llmClientFactory = factory,
            traceRecorder = trace,
            recordingService = mockk(relaxed = true),
            browserSessionManager = browserSessionManager
        )
    }

    private class FakeBrowserBridge : BrowserDevtoolsBridge {
        var closeCalls = 0
            private set

        override suspend fun preflight() = Unit

        override suspend fun fetchVersion(): DevtoolsVersion =
            DevtoolsVersion(
                browser = "Chrome/130",
                protocolVersion = "1.3",
                webSocketDebuggerUrl = "ws://test",
                userAgent = null,
            )

        override suspend fun listPageTargets(): List<PageTarget> = emptyList()

        override fun close() {
            closeCalls++
        }
    }

    private class FakeCdpConnectionFactory : CdpConnectionFactory {
        val connections = mutableListOf<FakeCdpConnection>()

        override suspend fun connect(
            url: String,
            onMessage: (String) -> Unit,
            onFailure: (Throwable) -> Unit,
            onClosed: (CdpConnectionClosedException) -> Unit,
        ): CdpConnection {
            val connection = FakeCdpConnection(onMessage)
            connections.add(connection)
            return connection
        }
    }

    private class FakeCdpConnection(
        private val onMessage: (String) -> Unit,
    ) : CdpConnection {
        var closeCalls = 0
            private set

        override fun send(text: String) {
            val request = Json.parseToJsonElement(text).jsonObject
            val id = request["id"]!!.jsonPrimitive.int
            val method = request["method"]!!.jsonPrimitive.content
            val result = when (method) {
                "Target.createTarget" -> buildJsonObject { put("targetId", "blank-page") }
                "Target.attachToTarget" -> buildJsonObject { put("sessionId", "session-1") }
                else -> buildJsonObject { }
            }
            onMessage(
                buildJsonObject {
                    put("id", id)
                    put("result", result)
                }.toString()
            )
        }

        override fun close() {
            closeCalls++
        }
    }
}
