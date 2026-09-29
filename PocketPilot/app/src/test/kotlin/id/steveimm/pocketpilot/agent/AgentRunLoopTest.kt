package id.steveimm.pocketpilot.agent

import id.steveimm.pocketpilot.test.testModelCatalog

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.LLMStreamEvent
import id.steveimm.pocketpilot.llm.LLMToolCall
import id.steveimm.pocketpilot.llm.ResponsesResult
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionId
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.platform.ActionResult
import id.steveimm.pocketpilot.platform.AndroidPlatform
import id.steveimm.pocketpilot.platform.AppInfo
import id.steveimm.pocketpilot.platform.DisplayInfo
import id.steveimm.pocketpilot.platform.UIAction
import id.steveimm.pocketpilot.session.SessionServices
import id.steveimm.pocketpilot.test.FakeAndroidPlatform
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.PolicyEngine
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolRouter
import id.steveimm.pocketpilot.tool.impl.ReadScreenTool
import id.steveimm.pocketpilot.trace.NoopTraceRecorder
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Test

/** Characterization tests for the Agent.run() control-loop FSM. */
@OptIn(ExperimentalCoroutinesApi::class)
class AgentRunLoopTest {

    @Test
    fun `direct reply never reads the phone and keeps the user message unchanged`() = runTest {
        val platform = object : AndroidPlatform by FakeAndroidPlatform() {
            override suspend fun captureScreen(): ScreenSnapshot = error("Unexpected screen capture")
            override fun getCurrentPackageName(): String? = error("Unexpected app inspection")
        }
        val llm = ProgrammableLLMClient(listOf(LLMBehavior.TextOnly("Reply")))
        val history = HistoryManager()
        assertThat(newAgent(llm, platform = platform, historyManager = history).run()).isEqualTo(AgentStopReason.Finished("Reply"))
        assertThat(llm.requests.single()).hasSize(1)
        assertThat(llm.requests.single().single().asEasyInputMessage().content().asTextInput()).isEqualTo("goal")
        assertThat(history.getAll().filterIsInstance<id.steveimm.pocketpilot.history.ResponseItem.Message>()
            .any { it.kind == id.steveimm.pocketpilot.history.MessageKind.SCREEN_OBSERVATION }).isFalse()
    }

    @Test
    fun `explicit screen request captures only before the next model turn`() = runTest {
        var captures = 0
        val platform = object : AndroidPlatform by FakeAndroidPlatform() {
            override suspend fun captureScreen(): ScreenSnapshot {
                captures++
                return ScreenSnapshot(1, emptyList())
            }
        }
        val llm = ProgrammableLLMClient(listOf(LLMBehavior.Continue, LLMBehavior.TextOnly("Screen inspected")))
        assertThat(newAgent(llm, platform = platform).run()).isEqualTo(AgentStopReason.Finished("Screen inspected"))
        assertThat(captures).isEqualTo(1)
        assertThat(llm.requests[0]).hasSize(1)
        assertThat(llm.requests[1].last().asEasyInputMessage().content().asTextInput()).contains("Foreground app")
    }

    @Test
    fun `Continue outcome loops until evalTurnBudget reached`() = runTest {
        // evalTurnBudget = 2: two Continue turns run, then the loop stops with Error before turn 3.
        val llm = ProgrammableLLMClient(
            listOf(LLMBehavior.Continue, LLMBehavior.Continue)
        )
        val agent = newAgent(llm, evalTurnBudget = 2)

        val reason = agent.run()

        assertThat(reason).isInstanceOf(AgentStopReason.Error::class.java)
        assertThat((reason as AgentStopReason.Error).message).contains("Eval turn budget")
        assertThat(llm.callCount).isEqualTo(2)
    }

    @Test
    fun `native final answer stops with Finished`() = runTest {
        val llm = ProgrammableLLMClient(listOf(LLMBehavior.TextOnly("done")))
        val agent = newAgent(llm)

        val reason = agent.run()

        assertThat(reason).isInstanceOf(AgentStopReason.Finished::class.java)
        assertThat((reason as AgentStopReason.Finished).message).isEqualTo("done")
    }

    @Test
    fun `blocked native answer finishes without claiming success`() = runTest {
        val reason = newAgent(ProgrammableLLMClient(listOf(LLMBehavior.TextOnly("Cannot open the missing app.")))).run()
        assertThat(reason).isEqualTo(AgentStopReason.Finished("Cannot open the missing app."))
    }

    @Test
    fun `non recoverable error stops immediately with Error`() = runTest {
        val llm = ProgrammableLLMClient(
            listOf(LLMBehavior.Throw(UnknownHostException("dns")))
        )
        val agent = newAgent(llm)

        val reason = agent.run()

        assertThat(reason).isInstanceOf(AgentStopReason.Error::class.java)
        assertThat(llm.callCount).isEqualTo(1) // no retry attempted
    }

    @Test
    fun `recoverable error retries within budget and can recover via Continue`() = runTest {
        val llm = ProgrammableLLMClient(
            listOf(
                LLMBehavior.Throw(SocketTimeoutException("t1")), // turn 1: error -> retry
                LLMBehavior.Continue,                            // turn 2: continue -> reset retry
                LLMBehavior.TextOnly("done")                     // turn 3: complete
            )
        )
        val agent = newAgent(llm)

        val reason = agent.run()

        assertThat(reason).isInstanceOf(AgentStopReason.Finished::class.java)
        assertThat(llm.callCount).isEqualTo(3)
    }

    @Test
    fun `recoverable error exhausts retry budget and stops with Error`() = runTest {
        val llm = ProgrammableLLMClient(
            listOf(
                LLMBehavior.Throw(SocketTimeoutException("t1")),
                LLMBehavior.Throw(SocketTimeoutException("t2")) // back-to-back -> retryCount=1, can't retry
            )
        )
        val agent = newAgent(llm)

        val reason = agent.run()

        assertThat(reason).isInstanceOf(AgentStopReason.Error::class.java)
        assertThat(llm.callCount).isEqualTo(2)
    }

    @Test
    fun `Continue resets retry counter so a later error gets a fresh retry`() = runTest {
        val llm = ProgrammableLLMClient(
            listOf(
                LLMBehavior.Throw(SocketTimeoutException("t1")), // retry++
                LLMBehavior.Continue,                            // retry := 0
                LLMBehavior.Throw(SocketTimeoutException("t2")), // retry++ (because reset)
                LLMBehavior.TextOnly("done")                     // succeeds
            )
        )
        val agent = newAgent(llm)

        val reason = agent.run()

        assertThat(reason).isInstanceOf(AgentStopReason.Finished::class.java)
        assertThat(llm.callCount).isEqualTo(4)
    }

    @Test
    fun `recoverable error retries indefinitely without a turn-count gate`() = runTest {
        // Regression for removal of `hasRemainingTurns` from the retry gate. The loop must keep retrying until the retry counter itself is
        // exhausted — a high turnCount alone should not block recovery.
        val llm = ProgrammableLLMClient(
            listOf(
                LLMBehavior.Continue,                            // turn 1
                LLMBehavior.Continue,                            // turn 2
                LLMBehavior.Continue,                            // turn 3
                LLMBehavior.Throw(SocketTimeoutException("t")), // turn 4: error -> retry (no turn gate)
                LLMBehavior.TextOnly("recovered")                // turn 5: success
            )
        )
        val agent = newAgent(llm)

        val reason = agent.run()

        assertThat(reason).isInstanceOf(AgentStopReason.Finished::class.java)
        assertThat((reason as AgentStopReason.Finished).message).isEqualTo("recovered")
        assertThat(llm.callCount).isEqualTo(5)
    }

    @Test
    fun `stop request before run causes UserRequested without invoking LLM`() = runTest {
        val llm = ProgrammableLLMClient(listOf(LLMBehavior.TextOnly("never")))
        val agent = newAgent(llm)
        agent.stop()

        val reason = agent.run()

        assertThat(reason).isEqualTo(AgentStopReason.UserRequested)
        assertThat(llm.callCount).isEqualTo(0)
    }

    @Test
    fun `cancellation signal completed before run causes UserRequested`() = runTest {
        val llm = ProgrammableLLMClient(listOf(LLMBehavior.TextOnly("never")))
        val cancellation = CompletableDeferred<AgentStopReason>().apply {
            complete(AgentStopReason.UserRequested)
        }
        val agent = newAgent(llm, cancellationSignal = cancellation)

        val reason = agent.run()

        assertThat(reason).isEqualTo(AgentStopReason.UserRequested)
        assertThat(llm.callCount).isEqualTo(0)
    }

    @Test
    fun `pause then resume then stop completes the pause Deferred`() = runTest(
        UnconfinedTestDispatcher()
    ) {
        // GatedLLMClient parks each turn on `awaitTurn()` so we can interleave
        // pause/resume/stop deterministically between turns.
        val llm = GatedLLMClient()
        val agent = newAgent(llm)

        val runJob = async { agent.run() }
        // Allow turn 1 to complete and re-enter the loop.
        llm.awaitTurnCalled()
        llm.completeTurn(LLMBehavior.Continue)

        llm.awaitTurnCalled()
        val pauseConfirmed = agent.pause()
        llm.completeTurn(LLMBehavior.Continue)
        pauseConfirmed.await()

        agent.resume()
        // After resume, loop runs another turn — let it queue and then stop.
        llm.awaitTurnCalled()
        agent.stop()
        llm.completeTurn(LLMBehavior.Continue)

        val reason = runJob.await()
        assertThat(reason).isEqualTo(AgentStopReason.UserRequested)
    }

    @Test
    fun `stop while paused unblocks the loop and exits with UserRequested`() = runTest(
        UnconfinedTestDispatcher()
    ) {
        val llm = GatedLLMClient()
        val agent = newAgent(llm)

        val runJob = async { agent.run() }
        llm.awaitTurnCalled()
        val pauseConfirmed = agent.pause()
        llm.completeTurn(LLMBehavior.Continue)
        pauseConfirmed.await()

        agent.stop()

        val reason = runJob.await()
        assertThat(reason).isEqualTo(AgentStopReason.UserRequested)
    }

    @Test
    fun `in turn Cancelled outcome maps to UserRequested`() = runTest(
        UnconfinedTestDispatcher()
    ) {
        val cancellation = CompletableDeferred<AgentStopReason>()
        val platform = CancellingCapturePlatform(cancellation)
        val llm = ProgrammableLLMClient(listOf(LLMBehavior.Continue))
        val agent = newAgent(
            llm,
            cancellationSignal = cancellation,
            platform = platform
        )

        val reason = agent.run()

        assertThat(reason).isEqualTo(AgentStopReason.UserRequested)
        assertThat(platform.captureCount).isEqualTo(1)
        assertThat(llm.callCount).isEqualTo(1) // only the initial screen request ran
    }

    @Test
    fun `consecutive compactor Failed×3 stops the loop with Error`() = runTest {
        // Continue×2 is enough — the loop breaks on the 3rd maybeCompact() failure
        // BEFORE turn 3 reaches the LLM.
        val llm = ProgrammableLLMClient(
            listOf(LLMBehavior.Continue, LLMBehavior.Continue)
        )
        // A compactor wired so every maybeCompact() trips Failed: trigger threshold
        // is below the seeded history's token count, but the inner LLM throws.
        val failingCompactorLlm = object : LLMClient() {
            var calls = 0
                private set

            override suspend fun chatWithTools(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String,
        maxOutputTokens: Long?,
            ): ResponsesResult {
                calls++
                throw RuntimeException("summary boom #$calls")
            }

            override fun chatWithToolsStreaming(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String
            ): Flow<LLMStreamEvent> = flow { emit(LLMStreamEvent.Completed()) }
        }
        val compactor = id.steveimm.pocketpilot.history.Compactor(
            llmClient = failingCompactorLlm,
            model = id.steveimm.pocketpilot.llm.ModelEntry(
                name = "test-compactor",
                displayName = "Test Compactor",
                modelId = "test-compactor",
                contextWindow = 100,
            ),
            initialPrompt = "",
            updatePrompt = "",
            staticOverheadTokens = 0,
            reserveTokens = 10,
            keepRecentTokens = 5,
        )

        val history = HistoryManager().apply {
            // Pre-seed so historyTokens > triggerTokens (= 90) and findSafeCutPoint
            // can locate a Message boundary in the kept tail.
            repeat(4) {
                addItem(id.steveimm.pocketpilot.history.ResponseItem.Message(
                    id.steveimm.pocketpilot.history.MessageKind.ASSISTANT_TEXT,
                    "x".repeat(200)
                ))
            }
        }

        val reason = newAgent(
            llm,
            compactor = compactor,
            historyManager = history,
        ).run()

        assertThat(reason).isInstanceOf(AgentStopReason.Error::class.java)
        assertThat((reason as AgentStopReason.Error).message).contains("Auto-compaction failed 3")
        assertThat(failingCompactorLlm.calls).isEqualTo(3)
        // Only two turns executed before the breaker tripped on the 3rd pre-turn check.
        assertThat(llm.callCount).isEqualTo(2)
    }

    private fun newAgent(
        llm: LLMClient,
        cancellationSignal: CompletableDeferred<AgentStopReason> = CompletableDeferred(),
        platform: AndroidPlatform = FakeAndroidPlatform(),
        evalTurnBudget: Int? = null,
        compactor: id.steveimm.pocketpilot.history.Compactor? = null,
        historyManager: HistoryManager = HistoryManager(),
    ): Agent {
        val toolRegistry = ToolRegistry().apply {
            register(ReadScreenTool())
            register(id.steveimm.pocketpilot.tool.impl.OpenAppTool())
        }
        val policyEngine = PolicyEngine(appClassifier = AppClassifier(emptyMap()))
        val sessionConfig = SessionConfig(
            actionDelayMs = 0,
            llm = SessionLlmConfig(baseUrl = "http://localhost:8000/v1")
        )
        val testCatalog = testModelCatalog(
            """{"gpt-5.2":{"display_name":"GPT-5.2","model_id":"gpt-5.2"}}"""
        )
        val services = SessionServices(
            toolRegistry = toolRegistry,
            toolRouter = ToolRouter(toolRegistry, policyEngine),
            historyManager = historyManager,
            policyEngine = policyEngine,
            appClassifier = AppClassifier(emptyMap()),
            platform = platform,
            config = sessionConfig,
            llmClient = llm,
            modelCatalog = testCatalog,
            llmClientFactory = LLMClientFactory.forTest(testCatalog, llm),
            traceRecorder = NoopTraceRecorder,
            recordingService = io.mockk.mockk(relaxed = true)
        )
        return Agent(
            config = AgentExecutionConfig(
                goal = "goal",
                sessionId = SessionId.generate(),
                uiSettleDelayMs = 0,
                systemPrompt = "test prompt",
                evalTurnBudget = evalTurnBudget,
            ),
            services = services,
            compactor = compactor ?: noopCompactor(),
            eventEmitter = {},
            cancellationSignal = cancellationSignal
        )
    }
}

/** Per-call scripted behaviors for [ProgrammableLLMClient]. */
private sealed class LLMBehavior {
    /** A screen request keeps the loop running. */
    data object Continue : LLMBehavior()

    /** Native final answer ends the loop. */
    data class TextOnly(val text: String) : LLMBehavior()


    /** Throws on streaming — classified by [TurnErrorClassifier]. */
    data class Throw(val error: Throwable) : LLMBehavior()
}

/** Returns a scripted behavior per call. Throws if the script runs out, which forces tests to be explicit about expected call counts. */
private class ProgrammableLLMClient(
    private val script: List<LLMBehavior>
) : LLMClient() {
    var callCount: Int = 0
        private set
    val requests = mutableListOf<List<ResponseInputItem>>()

    override suspend fun chatWithTools(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String,
        maxOutputTokens: Long?,
    ): ResponsesResult {
        // Agent uses streaming exclusively in this path; non-streaming is a
        // sanity guard so unexpected callers are easy to spot.
        error("non-streaming chatWithTools should not be invoked by Agent.run()")
    }

    override fun chatWithToolsStreaming(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String
    ): Flow<LLMStreamEvent> = flow {
        requests += inputItems
        val index = callCount
        callCount += 1
        val behavior = script.getOrNull(index)
            ?: error("ProgrammableLLMClient ran out of scripted behaviors at call $index")
        emit(LLMStreamEvent.Created("resp-$index"))
        when (behavior) {
            LLMBehavior.Continue -> emitReadScreen()
            is LLMBehavior.TextOnly -> {
                emit(LLMStreamEvent.TextDelta(behavior.text))
                emit(LLMStreamEvent.Completed())
            }
            is LLMBehavior.Throw -> throw behavior.error
        }
    }
}

/** Like [ProgrammableLLMClient] but each call parks until the test calls [completeTurn]. Lets tests interleave pause/resume/stop
 * deterministically. */
private class GatedLLMClient : LLMClient() {
    private val turnEntered = Channel<Unit>(capacity = Channel.UNLIMITED)
    private val turnRelease = Channel<LLMBehavior>(capacity = Channel.UNLIMITED)

    suspend fun awaitTurnCalled() {
        turnEntered.receive()
    }

    fun completeTurn(behavior: LLMBehavior) {
        check(turnRelease.trySend(behavior).isSuccess)
    }

    override suspend fun chatWithTools(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String,
        maxOutputTokens: Long?,
    ): ResponsesResult = error("non-streaming chatWithTools should not be invoked")

    override fun chatWithToolsStreaming(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String
    ): Flow<LLMStreamEvent> = flow {
        turnEntered.send(Unit)
        val behavior = turnRelease.receive()
        emit(LLMStreamEvent.Created("gated"))
        when (behavior) {
            LLMBehavior.Continue -> emitReadScreen()
            is LLMBehavior.TextOnly -> {
                emit(LLMStreamEvent.TextDelta(behavior.text))
                emit(LLMStreamEvent.Completed())
            }
            is LLMBehavior.Throw -> throw behavior.error
        }
    }
}

/** Platform whose [captureScreen] completes the agent's cancellation signal, exercising the `isTurnCancelled()` check inside
 * `AgentTurnRunner.executeTurn`. */
private class CancellingCapturePlatform(
    private val signal: CompletableDeferred<AgentStopReason>
) : AndroidPlatform {
    override val mode: id.steveimm.pocketpilot.protocol.PlatformMode = id.steveimm.pocketpilot.protocol.PlatformMode.ACCESSIBILITY
    var captureCount: Int = 0
        private set

    override suspend fun captureScreen(): ScreenSnapshot {
        captureCount += 1
        signal.complete(AgentStopReason.UserRequested)
        return ScreenSnapshot(timestamp = 0L, elements = emptyList())
    }

    override suspend fun performAction(action: UIAction): ActionResult = ActionResult.Success()
    override fun hasRequiredPermissions(): Boolean = true
    override fun getCurrentPackageName(): String? = "com.example.fake"
    override fun getDisplayInfo(): DisplayInfo =
        DisplayInfo(widthPixels = 1080, heightPixels = 1920, density = 2f)
    override suspend fun getInstalledApps(): List<AppInfo> = emptyList()
    override suspend fun launchApp(packageName: String): ActionResult = ActionResult.Success()
}

private suspend fun kotlinx.coroutines.flow.FlowCollector<LLMStreamEvent>.emitReadScreen() {
    emit(LLMStreamEvent.ToolCallDone(LLMToolCall("read_screen", "read_screen", """{"delay_ms":1}""")))
    emit(LLMStreamEvent.Completed("tool_calls"))
}
