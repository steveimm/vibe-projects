package id.steveimm.pocketpilot.session

import android.util.Log
import id.steveimm.pocketpilot.history.model.SessionInfo
import id.steveimm.pocketpilot.protocol.Op
import id.steveimm.pocketpilot.protocol.SessionState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex

/** Coordinates session lifecycle and input queuing. */
class SessionCoordinator(private val scope: CoroutineScope) {

    companion object {
        private const val TAG = "SessionCoordinator"
        private const val SHUTDOWN_GRACE_DELAY_MS = 100L
    }

    private val mutex = Mutex()
    private val pendingInputs = mutableListOf<String>()
    private var stateObserverJob: Job? = null

    var currentSession: AgentSession? = null
        private set

    var selectedSessionForReload: SessionInfo? = null

    /** File name of the last session that died (Shutdown). Used for auto-reload. */
    private var lastDeadSessionFileName: String? = null

    /** Submit user input to the current session. */
    suspend fun submit(text: String): SubmitResult {
        mutex.lock()
        try {
            val session = currentSession
                ?: return SubmitResult.NO_SESSION
            return when (session.state.value) {
                SessionState.Shutdown -> {
                    lastDeadSessionFileName =
                        session.getServices().recordingService.getCurrentFileName()
                    teardownLocked()
                    SubmitResult.SESSION_DEAD
                }
                SessionState.Running, SessionState.Paused, SessionState.TakeoverPending -> {
                    pendingInputs.add(text)
                    SubmitResult.QUEUED
                }
                else -> {
                    session.submit(Op.UserInput(text))
                    SubmitResult.SENT
                }
            }
        } finally {
            mutex.unlock()
        }
    }

    /** Create a session and submit the first input, all under the creation lock. */
    suspend fun createAndSubmit(
        text: String,
        create: suspend () -> AgentSession?
    ): CreateResult {
        if (!mutex.tryLock()) return CreateResult.LockBusy
        try {
            val session = try {
                create()
            } catch (t: Throwable) {
                pendingInputs.clear()
                throw t
            }
            if (session == null) {
                pendingInputs.clear()
                return CreateResult.Aborted
            }
            currentSession = session
            observeSessionState(session)
            session.submit(Op.UserInput(text))
            drainLocked(session)
            return CreateResult.Success
        } finally {
            mutex.unlock()
        }
    }

    /** Directly queue input for delivery when the next session becomes available. */
    fun enqueue(text: String) {
        pendingInputs.add(text)
    }

    /** Attach an externally-managed session (e.g., rebound from service). Starts state observation for event-driven drain. */
    fun attachSession(session: AgentSession) {
        currentSession = session
        observeSessionState(session)
    }

    /** Detach the current session without shutting it down. Used when switching to history viewing mode. */
    fun detachSession() {
        stateObserverJob?.cancel()
        stateObserverJob = null
        currentSession = null
        pendingInputs.clear()
        lastDeadSessionFileName = null
    }

    /** Consume the file name of the last session that died (Shutdown). Returns the file name and clears it so it's only used once. Used
     * by callers to set up auto-reload from checkpoint. */
    fun consumeDeadSessionFileName(): String? {
        val f = lastDeadSessionFileName
        lastDeadSessionFileName = null
        return f
    }

    /** Shutdown and clear the current session. */
    suspend fun clearSession() {
        mutex.lock()
        try {
            val session = currentSession ?: return
            try {
                session.submit(Op.Shutdown)
                delay(SHUTDOWN_GRACE_DELAY_MS)
                Log.d(TAG, "Session shutdown completed")
            } catch (e: Exception) {
                Log.w(TAG, "Error shutting down session: ${e.message}")
            }
            teardownLocked()
            lastDeadSessionFileName = null
        } finally {
            mutex.unlock()
        }
    }

    private fun teardownLocked() {
        stateObserverJob?.cancel()
        stateObserverJob = null
        currentSession = null
        pendingInputs.clear()
    }

    private fun observeSessionState(session: AgentSession) {
        stateObserverJob?.cancel()
        stateObserverJob = scope.launch {
            session.state.collect { state ->
                if (state == SessionState.Idle || state == SessionState.Created) {
                    drainPending()
                }
            }
        }
    }

    private suspend fun drainPending() {
        mutex.lock()
        try {
            val session = currentSession ?: return
            drainLocked(session)
        } finally {
            mutex.unlock()
        }
    }

    private suspend fun drainLocked(session: AgentSession) {
        while (pendingInputs.isNotEmpty()) {
            val state = session.state.value
            if (state != SessionState.Idle && state != SessionState.Created) break
            session.submit(Op.UserInput(pendingInputs.removeAt(0)))
        }
    }
}

/** Result of [SessionCoordinator.submit]. */
enum class SubmitResult {
    /** Input was sent to the session immediately. */
    SENT,
    /** Session is busy; input queued for automatic drain. */
    QUEUED,
    /** No session exists; caller should create one. */
    NO_SESSION,
    /** Session was dead (shutdown); caller should create a new one. */
    SESSION_DEAD
}

/** Result of [SessionCoordinator.createAndSubmit]. */
sealed class CreateResult {
    /** Session created; first input submitted. */
    data object Success : CreateResult()
    /** Creation lock held by another caller; caller should [SessionCoordinator.enqueue]. */
    data object LockBusy : CreateResult()
    /** Creation factory returned null (explicit abort); pending inputs cleared. */
    data object Aborted : CreateResult()
}
