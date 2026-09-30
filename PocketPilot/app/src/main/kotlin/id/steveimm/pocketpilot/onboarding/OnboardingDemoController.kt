package id.steveimm.pocketpilot.onboarding

import android.util.Log
import id.steveimm.pocketpilot.app.AgentService
import id.steveimm.pocketpilot.app.AppSettingsState
import id.steveimm.pocketpilot.app.ServerCredentialStoreHolder
import id.steveimm.pocketpilot.perception.PerceptionConfig
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.TaskOutcome
import id.steveimm.pocketpilot.protocol.Op
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.protocol.ScreenCaptured
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
import id.steveimm.pocketpilot.protocol.TaskCompleted
import id.steveimm.pocketpilot.session.AgentSession
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

/** Runs a throwaway demo session during onboarding. */
class OnboardingDemoController(
    private val settingsState: AppSettingsState,
    private val scope: CoroutineScope
) {

    companion object {
        private const val TAG = "OnboardingDemo"
        private const val DEMO_GOAL = "Open the Settings app"
        private const val TIMEOUT_MS = 60_000L
        private const val SETTINGS_PACKAGE = "com.android.settings"

    }

    private var demoJob: Job? = null

    fun run(
        onSuccess: (message: String) -> Unit,
        onFailure: (reason: String) -> Unit,
        onBringToFront: () -> Unit,
        onStopped: () -> Unit,
    ) {
        val previousJob = demoJob
        previousJob?.cancel()
        demoJob = scope.launch {
            previousJob?.join()
            val service = AgentService.instance
            if (service == null) {
                withContext(Dispatchers.Main) {
                    onFailure("Accessibility service not available")
                }
                return@launch
            }

            val credentialStore = ServerCredentialStoreHolder.get(service.applicationContext)

            var ownedSession: AgentSession? = null
            try {
                val config = SessionConfig(
                    approvalMode = ApprovalMode.AUTO_APPROVE,
                    llm = SessionLlmConfig(baseUrl = settingsState.serverBaseUrl),
                    perceptionConfig = PerceptionConfig(),
                    platformMode = PlatformMode.ACCESSIBILITY,
                    mainModel = settingsState.serverModelId
                )

                val visualizer = service.getActionVisualizer()
                val touchGate = service.getOverlayTouchGate()

                val session = withContext(Dispatchers.IO) {
                    AgentSession.create(
                        config = config,
                        service = service,
                        scope = service.serviceScope,
                        credentialStore = credentialStore,
                        visualizer = visualizer,
                        overlayTouchGate = touchGate
                    ).also { ownedSession = it }
                }

                // Register with service for overlay visualization
                service.observeExternalSession(session, PlatformMode.ACCESSIBILITY)

                // Collect events in background
                var lastPackageName: String? = null
                var taskCompleted: TaskCompleted? = null

                val eventJob = launch {
                    session.events.collect { event ->
                        when (event) {
                            is ScreenCaptured -> {
                                lastPackageName = event.packageName
                            }
                            is TaskCompleted -> {
                                taskCompleted = event
                            }
                            else -> {}
                        }
                    }
                }

                // Submit demo goal
                session.submit(Op.UserInput(DEMO_GOAL))
                Log.d(TAG, "Demo goal submitted: $DEMO_GOAL")

                // Wait for completion or timeout
                val completed = withTimeoutOrNull(TIMEOUT_MS) {
                    while (taskCompleted == null) {
                        delay(200)
                    }
                    taskCompleted
                }

                eventJob.cancel()

                // Deliver callbacks on Main dispatcher (they mutate Compose state)
                withContext(Dispatchers.Main) {
                    if (completed != null) {
                        val runFinished = completed.outcome == TaskOutcome.FINISHED
                        val isSettingsOpen = lastPackageName == SETTINGS_PACKAGE

                        if (runFinished && isSettingsOpen) {
                            Log.d(TAG, "Demo succeeded: Settings app opened")
                            onBringToFront()
                            onSuccess("Settings app opened successfully!")
                        } else if (runFinished) {
                            Log.w(TAG, "Demo finished without verifying Settings: package=$lastPackageName")
                            onBringToFront()
                            onFailure("Settings did not open. Check the model response and try again.")
                        } else if (completed.outcome == TaskOutcome.USER_STOPPED) {
                            onBringToFront()
                            onStopped()
                        } else {
                            val reason = when (completed.outcome) {
                                TaskOutcome.ERROR -> "Demo encountered an error"
                                else -> "Demo ended: ${completed.outcome}"
                            }
                            Log.w(TAG, "Demo failed: ${completed.outcome}")
                            onBringToFront()
                            onFailure(reason)
                        }
                    } else {
                        Log.w(TAG, "Demo timed out after ${TIMEOUT_MS}ms")
                        onBringToFront()
                        onFailure("The demo timed out before opening Settings.")
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "Demo failed with exception", e)
                withContext(Dispatchers.Main) {
                    onFailure("Demo failed: ${e.message}")
                }
            } finally {
                withContext(NonCancellable) { shutdownSession(ownedSession) }
            }
        }
    }

    fun cancel() {
        demoJob?.cancel()
    }

    private suspend fun shutdownSession(session: AgentSession?) {
        try {
            session?.submit(Op.Shutdown)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "Demo session shutdown error: ${e.message}")
        }
    }
}
