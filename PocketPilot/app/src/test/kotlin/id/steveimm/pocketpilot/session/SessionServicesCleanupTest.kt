package id.steveimm.pocketpilot.session

import id.steveimm.pocketpilot.test.testModelCatalog

import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
import id.steveimm.pocketpilot.test.FakeAndroidPlatform
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.PolicyEngine
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolRouter
import id.steveimm.pocketpilot.trace.TraceRecorder
import com.google.common.truth.Truth.assertThat
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import id.steveimm.pocketpilot.llm.LLMStreamEvent
import id.steveimm.pocketpilot.llm.ResponsesResult
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import io.mockk.every
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.runBlocking
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
    fun `cleanup still closes resources when cancelling tools and clearing history fail`() = runBlocking {
        val router = mockk<ToolRouter>(relaxed = true)
        every { router.cancelAll() } throws IllegalStateException("cancel failed")
        val history = mockk<HistoryManager>(relaxed = true)
        every { history.clear() } throws IllegalStateException("history failed")
        val client = mockk<LLMClient>(relaxed = true)
        val factory = mockk<LLMClientFactory>(relaxed = true)
        val trace = mockk<TraceRecorder>(relaxed = true)
        val services = buildServices(client, factory, trace, router = router, history = history)

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
        router: ToolRouter? = null,
        history: HistoryManager = HistoryManager(),
    ): SessionServices {
        val toolRegistry = ToolRegistry()
        val policyEngine = PolicyEngine(appClassifier = AppClassifier(emptyMap()))
        val toolRouter = router ?: ToolRouter(toolRegistry, policyEngine)
        val catalog =
            testModelCatalog(
                """{"gpt-5.2":{"display_name":"GPT-5.2","model_id":"gpt-5.2"}}"""
            )
        return SessionServices(
            toolRegistry = toolRegistry,
            toolRouter = toolRouter,
            historyManager = history,
            policyEngine = policyEngine,
            appClassifier = AppClassifier(emptyMap()),
            platform = FakeAndroidPlatform(),
            config = SessionConfig(
                actionDelayMs = 0,
                llm = SessionLlmConfig(baseUrl = "http://localhost:8000/v1")
            ),
            llmClient = llmClient,
            modelCatalog = catalog,
            llmClientFactory = factory,
            traceRecorder = trace,
            recordingService = mockk(relaxed = true),
        )
    }

}
