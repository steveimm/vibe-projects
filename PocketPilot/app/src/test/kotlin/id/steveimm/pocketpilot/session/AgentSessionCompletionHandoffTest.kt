package id.steveimm.pocketpilot.session

import id.steveimm.pocketpilot.test.testModelCatalog

import android.accessibilityservice.AccessibilityService
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.LLMStreamEvent
import id.steveimm.pocketpilot.llm.ResponsesResult
import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.platform.ActionResult
import id.steveimm.pocketpilot.platform.AndroidPlatform
import id.steveimm.pocketpilot.platform.AppInfo
import id.steveimm.pocketpilot.platform.DisplayInfo
import id.steveimm.pocketpilot.platform.UIAction
import id.steveimm.pocketpilot.protocol.*
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.PolicyEngine
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolRouter
import id.steveimm.pocketpilot.trace.NoopTraceRecorder
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AgentSessionCompletionHandoffTest {

    @Test
    fun `vd completion emits handoff with package and resolved label`() = runTest {
        val (session, _) = buildHandoffSession(
                scope = this,
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                currentPackage = "com.example.target",
                resolveLabel = { pkg -> if (pkg == "com.example.target") "Target App" else null },
        )
        val events = mutableListOf<AgentEvent>()
        val job = launch { session.events.collect { events.add(it) } }

        session.submit(Op.UserInput("goal"))
        advanceUntilIdle()

        val completed = events.filterIsInstance<TaskCompleted>().single()
        val handoff = completed.handoff
        assertThat(handoff).isNotNull()
        assertThat(handoff!!.appPackage).isEqualTo("com.example.target")
        assertThat(handoff.appLabel).isEqualTo("Target App")

        job.cancel()
    }

    @Test
    fun `vd completion drops self and systemui packages`() = runTest {
        val (session, _) = buildHandoffSession(
                scope = this,
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                currentPackage = "id.steveimm.pocketpilot",
                resolveLabel = { _ -> "ShouldNotResolve" },
        )
        val events = mutableListOf<AgentEvent>()
        val job = launch { session.events.collect { events.add(it) } }

        session.submit(Op.UserInput("goal"))
        advanceUntilIdle()

        val completed = events.filterIsInstance<TaskCompleted>().single()
        val handoff = completed.handoff
        assertThat(handoff).isNotNull()
        assertThat(handoff!!.appPackage).isNull()
        assertThat(handoff.appLabel).isNull()

        job.cancel()
    }

    @Test
    fun `vd completion with unresolvable package emits null label`() = runTest {
        val (session, _) = buildHandoffSession(
                scope = this,
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                currentPackage = "com.uninstalled.app",
                resolveLabel = { _ -> null },
        )
        val events = mutableListOf<AgentEvent>()
        val job = launch { session.events.collect { events.add(it) } }

        session.submit(Op.UserInput("goal"))
        advanceUntilIdle()

        val handoff = events.filterIsInstance<TaskCompleted>().single().handoff
        assertThat(handoff).isNotNull()
        assertThat(handoff!!.appPackage).isEqualTo("com.uninstalled.app")
        assertThat(handoff.appLabel).isNull()

        job.cancel()
    }

    @Test
    fun `vd completion drops blocked-tier package`() = runTest {
        val (session, _) = buildHandoffSession(
                scope = this,
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                currentPackage = "com.chase.sig.android",
                resolveLabel = { _ -> "Chase" },
                appTiers = mapOf("com.chase.sig.android" to AppTier.BLOCKED),
        )
        val events = mutableListOf<AgentEvent>()
        val job = launch { session.events.collect { events.add(it) } }

        session.submit(Op.UserInput("goal"))
        advanceUntilIdle()

        val completed = events.filterIsInstance<TaskCompleted>().single()
        val handoff = completed.handoff
        assertThat(handoff).isNotNull()
        assertThat(handoff!!.appPackage).isNull()
        assertThat(handoff.appLabel).isNull()

        job.cancel()
    }

    @Test
    fun `accessibility completion emits no handoff`() = runTest {
        val (session, _) = buildHandoffSession(
                scope = this,
                platformMode = PlatformMode.ACCESSIBILITY,
                currentPackage = "com.example.target",
                resolveLabel = { _ -> "ignored" },
        )
        val events = mutableListOf<AgentEvent>()
        val job = launch { session.events.collect { events.add(it) } }

        session.submit(Op.UserInput("goal"))
        advanceUntilIdle()

        val completed = events.filterIsInstance<TaskCompleted>().single()
        assertThat(completed.handoff).isNull()

        job.cancel()
    }

    private fun buildHandoffSession(
            scope: CoroutineScope,
            platformMode: PlatformMode,
            currentPackage: String?,
            resolveLabel: (String) -> String?,
            appTiers: Map<String, AppTier> = emptyMap(),
    ): Pair<AgentSession, PackageManager> {
        val packageManager = mockk<PackageManager>()
        every { packageManager.getApplicationInfo(any<String>(), any<Int>()) } answers {
            val pkg = firstArg<String>()
            if (resolveLabel(pkg) != null) {
                ApplicationInfo().apply { packageName = pkg }
            } else {
                throw PackageManager.NameNotFoundException(pkg)
            }
        }
        every { packageManager.getApplicationLabel(any()) } answers {
            val info = firstArg<ApplicationInfo>()
            resolveLabel(info.packageName) ?: ""
        }
        val service = mockk<AccessibilityService>(relaxed = true)
        every { service.packageManager } returns packageManager
        every { service.packageName } returns "id.steveimm.pocketpilot"

        val platform = FixedModePlatform(mode = platformMode, packageName = currentPackage)
        val appClassifier = AppClassifier(appTiers)
        val toolRegistry = ToolRegistry()
        val policyEngine = PolicyEngine(appClassifier = appClassifier)
        val toolRouter = ToolRouter(toolRegistry, policyEngine)
        val config = SessionConfig(actionDelayMs = 0)
        val testCatalog =
                testModelCatalog(
                        """{"gpt-5.2":{"display_name":"GPT-5.2","model_id":"gpt-5.2"}}"""
                )
        val llm = QuickCompletionLLMClient()
        val services =
                SessionServices(
                        toolRegistry = toolRegistry,
                        toolRouter = toolRouter,
                        historyManager = HistoryManager(),
                        policyEngine = policyEngine,
                        appClassifier = appClassifier,
                        platform = platform,
                        config = config,
                        llmClient = llm,
                        modelCatalog = testCatalog,
                        llmClientFactory = LLMClientFactory.forTest(testCatalog, llm),
                        traceRecorder = NoopTraceRecorder,
                        recordingService = mockk(relaxed = true)
                )
        val session = AgentSession.createWithServices(
                config = config,
                service = service,
                scope = scope,
                services = services
        )
        return session to packageManager
    }
}

private class FixedModePlatform(
        override val mode: PlatformMode,
        private val packageName: String?,
) : AndroidPlatform {
    override suspend fun captureScreen(): ScreenSnapshot =
            ScreenSnapshot(timestamp = 0L, elements = emptyList())
    override suspend fun performAction(action: UIAction): ActionResult = ActionResult.Success()
    override fun hasRequiredPermissions(): Boolean = true
    override fun getCurrentPackageName(): String? = packageName
    override fun getDisplayInfo(): DisplayInfo =
            DisplayInfo(widthPixels = 1080, heightPixels = 1920, density = 2f)
    override suspend fun getInstalledApps(): List<AppInfo> = emptyList()
    override suspend fun launchApp(packageName: String): ActionResult = ActionResult.Success()
}

private class QuickCompletionLLMClient : LLMClient() {
    override suspend fun chatWithTools(
            systemPrompt: String,
            inputItems: List<ResponseInputItem>,
            tools: List<FunctionTool>,
            model: String,
        maxOutputTokens: Long?,
    ): ResponsesResult =
            ResponsesResult(textContent = "done", toolCalls = emptyList(), responseId = "resp")

    override fun chatWithToolsStreaming(
            systemPrompt: String,
            inputItems: List<ResponseInputItem>,
            tools: List<FunctionTool>,
            model: String
    ): Flow<LLMStreamEvent> = flow {
        emit(LLMStreamEvent.TextDelta("done"))
        emit(LLMStreamEvent.Completed())
    }
}
