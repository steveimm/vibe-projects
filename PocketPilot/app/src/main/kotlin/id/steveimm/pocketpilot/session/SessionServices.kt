package id.steveimm.pocketpilot.session

import android.content.Context
import android.util.Log
import id.steveimm.pocketpilot.auth.ServerCredentialStore
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.history.SessionRecordingService
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.ModelCatalog
import id.steveimm.pocketpilot.llm.ModelCatalogRepositoryHolder
import id.steveimm.pocketpilot.platform.AndroidPlatform
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.PolicyEngine
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolRouter
import id.steveimm.pocketpilot.trace.TraceRecorder
import kotlinx.coroutines.CoroutineScope

/** SessionServices - Dependency Injection container for all session-scoped services. */
class SessionServices internal constructor(
        val toolRegistry: ToolRegistry,
        val toolRouter: ToolRouter,
        val historyManager: HistoryManager,
        val policyEngine: PolicyEngine,
        val appClassifier: AppClassifier,
        val platform: AndroidPlatform,
        val config: SessionConfig,
        val llmClient: LLMClient,
        val modelCatalog: ModelCatalog,
        val llmClientFactory: LLMClientFactory,
        val traceRecorder: TraceRecorder,
        val recordingService: SessionRecordingService,
        val userResponseChannel: UserResponseChannel = UserResponseChannel(),
) {
    companion object {
        private const val TAG = "SessionServices"

        /** Create a new SessionServices container with all services initialized. */
        fun create(
                config: SessionConfig,
                platform: AndroidPlatform,
                credentialStore: ServerCredentialStore?,
                context: Context,
                scope: CoroutineScope,
                traceRecorder: TraceRecorder,
                appClassifier: AppClassifier
        ): SessionServices {
            Log.d(TAG, "Creating SessionServices...")

            val catalogRepository = ModelCatalogRepositoryHolder.get(context)
            val llmBootstrap = SessionLlmBootstrapper.create(
                    config = config,
                    catalogRepository = catalogRepository,
                    credentialStore = credentialStore,
            )
            val modelCatalog = llmBootstrap.modelCatalog
            val llmClientFactory = llmBootstrap.llmClientFactory
            val llmClient: LLMClient = llmBootstrap.llmClient
            Log.d(TAG, "Created LLMClient: ${llmClient.javaClass.simpleName}")

            val tooling = SessionToolingBootstrapper.create(
                approvalMode = config.approvalMode,
                appClassifier = appClassifier,
                excludedTools = config.excludedTools,
            )
            val policyEngine = tooling.policyEngine
            val toolRegistry = tooling.toolRegistry
            val toolRouter = tooling.toolRouter
            val history = SessionHistoryBootstrapper.create(context, scope)
            val historyManager = history.historyManager
            val recordingService = history.recordingService
            Log.i(TAG, "SessionServices created successfully")

            return SessionServices(
                    toolRegistry = toolRegistry,
                    toolRouter = toolRouter,
                    historyManager = historyManager,
                    policyEngine = policyEngine,
                    appClassifier = appClassifier,
                    platform = platform,
                    config = config,
                    llmClient = llmClient,
                    modelCatalog = modelCatalog,
                    llmClientFactory = llmClientFactory,
                    traceRecorder = traceRecorder,
                    recordingService = recordingService,
            )
        }

    }

    /** Cleanup all services. Aggregates per-step failures rather than aborting, so callers can surface partial teardown errors. */
    suspend fun cleanup(): CleanupResult {
        Log.d(TAG, "Cleaning up SessionServices...")

        val failures = mutableListOf<CleanupFailure>()
        runStep("toolRouter.cancelAll", failures) { toolRouter.cancelAll() }
        runStep("userResponseChannel.cancel", failures) { userResponseChannel.cancel() }
        runStep("historyManager.clear", failures) { historyManager.clear() }
        runStep("platform.stop", failures) { platform.stop() }
        runStep("llmClient.cleanup", failures) {
            if (!llmClientFactory.owns(llmClient)) llmClient.cleanup()
        }
        runStep("llmClientFactory.cleanupAll", failures) { llmClientFactory.cleanupAll() }
        // Flush/close trace last so we still capture teardown artifacts if needed
        runStep("traceRecorder.close", failures) { traceRecorder.close() }

        Log.i(TAG, "SessionServices cleaned up (failures=${failures.size})")
        return if (failures.isEmpty()) CleanupResult.Success else CleanupResult.PartialFailure(failures)
    }

    private suspend inline fun runStep(
        name: String,
        failures: MutableList<CleanupFailure>,
        block: () -> Unit
    ) {
        try {
            block()
        } catch (e: Exception) {
            Log.w(TAG, "$name failed (non-fatal)", e)
            failures.add(CleanupFailure(name, e))
        }
    }
}

data class CleanupFailure(val step: String, val cause: Throwable)

sealed class CleanupResult {
    object Success : CleanupResult()
    data class PartialFailure(val failures: List<CleanupFailure>) : CleanupResult()
}
