package id.steveimm.pocketpilot.ui.overlay

import android.util.Log
import id.steveimm.pocketpilot.protocol.AskUserType
import id.steveimm.pocketpilot.protocol.SessionEndReason
import id.steveimm.pocketpilot.protocol.TaskOutcome
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.protocol.TurnPhase
import id.steveimm.pocketpilot.protocol.compactThought
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleContext
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import id.steveimm.pocketpilot.ui.overlay.model.GlowState
import id.steveimm.pocketpilot.ui.overlay.model.deriveGlowState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** CapsuleStateHolder — single source of truth for Smart Capsule state. */
class CapsuleStateHolder {

    companion object {
        private const val TAG = "CapsuleStateHolder"
    }

    private val _mode = MutableStateFlow<CapsuleMode>(CapsuleMode.Hidden)
    val mode: StateFlow<CapsuleMode> = _mode.asStateFlow()

    private val _context = MutableStateFlow(CapsuleContext.MAIN_APP)
    val context: StateFlow<CapsuleContext> = _context.asStateFlow()

    private val _platformMode = MutableStateFlow(PlatformMode.ACCESSIBILITY)
    val platformMode: StateFlow<PlatformMode> = _platformMode.asStateFlow()

    private val _hasBubble = MutableStateFlow(true)
    val hasBubble: StateFlow<Boolean> = _hasBubble.asStateFlow()

    private val _turnPhase = MutableStateFlow<TurnPhase?>(null)
    val turnPhase: StateFlow<TurnPhase?> = _turnPhase.asStateFlow()

    /** True when agent is mid-turn (execution/planning). Used for supplement confirmation. */
    private val _isAgentMidTurn = MutableStateFlow(false)
    val isAgentMidTurn: StateFlow<Boolean> = _isAgentMidTurn.asStateFlow()

    /** Transient stop feedback flag. */
    private val _isStopPending = MutableStateFlow(false)
    val isStopPending: StateFlow<Boolean> = _isStopPending.asStateFlow()

    /** The mode before the current one, for transition animations. */
    var previousMode: CapsuleMode = CapsuleMode.Hidden
        private set

    /** Derived glow state — no parallel state machine needed. */
    val derivedGlowState: GlowState get() = deriveGlowState(_mode.value, _turnPhase.value)

    /** Whether there's an active task (derived from mode). */
    val hasActiveTask: Boolean
        get() =
            when (_mode.value) {
                is CapsuleMode.Running,
                is CapsuleMode.TakeoverPending,
                is CapsuleMode.Takeover,
                is CapsuleMode.WaitingForInput,
                is CapsuleMode.WaitingForAction,
                is CapsuleMode.WaitingForApproval -> true
                is CapsuleMode.Done,
                is CapsuleMode.Error,
                is CapsuleMode.Hidden -> false
            }


    fun setPlatformMode(mode: PlatformMode) { _platformMode.value = mode }

    fun setTurnPhase(phase: TurnPhase) {
        _turnPhase.value = phase
        if (_mode.value is CapsuleMode.Running) {
            val status = when (phase) {
                TurnPhase.PERCEPTION -> "Reading screen"
                TurnPhase.PLANNING -> "Thinking"
                TurnPhase.EXECUTION -> "Acting"
            }
            setMode(CapsuleMode.Running(status))
        }
    }

    fun setAgentMidTurn(midTurn: Boolean) { _isAgentMidTurn.value = midTurn }

    fun setContext(ctx: CapsuleContext) { _context.value = ctx }

    fun setHasBubble(enabled: Boolean) { _hasBubble.value = enabled }

    fun onTaskStarted(taskId: String, input: String) {
        _isStopPending.value = false
        _turnPhase.value = null
        setMode(CapsuleMode.Running(compactThought(input)))
    }

    fun onError(message: String) {
        _isStopPending.value = false
        setMode(CapsuleMode.Error(compactThought(message)))
    }

    fun onAskUser(type: AskUserType, message: String, callId: String) {
        setMode(
            when (type) {
                AskUserType.QUESTION -> CapsuleMode.WaitingForInput(
                    question = message, callId = callId,
                )
                AskUserType.ACTION -> CapsuleMode.WaitingForAction(
                    instruction = message, callId = callId,
                )
            }
        )
    }

    fun onApprovalRequired(
        callId: String,
        description: String,
        appLabel: String,
        packageName: String,
        reason: String,
    ) {
        setMode(CapsuleMode.WaitingForApproval(callId, description, appLabel, packageName, reason))
    }

    fun onApprovalResolved(callId: String): Boolean {
        val current = _mode.value as? CapsuleMode.WaitingForApproval ?: run {
            Log.d(TAG, "Ignoring approval resolved in ${_mode.value::class.simpleName}")
            return false
        }
        if (current.callId != callId) {
            Log.d(TAG, "Ignoring approval resolved: callId mismatch expected=${current.callId}, actual=$callId")
            return false
        }
        setMode(CapsuleMode.Running("Processing..."))
        return true
    }

    fun onTakeoverRequested() {
        val current = _mode.value as? CapsuleMode.Running ?: run {
            Log.d(TAG, "Ignoring takeover request in ${_mode.value::class.simpleName}")
            return
        }
        setMode(CapsuleMode.TakeoverPending(current.thought))
    }

    fun onTakeoverConfirmed() {
        val thought = when (val m = _mode.value) {
            is CapsuleMode.TakeoverPending -> m.lastThought
            is CapsuleMode.Running -> m.thought
            else -> {
                Log.d(TAG, "Ignoring takeover confirmed in ${_mode.value::class.simpleName}")
                return
            }
        }
        setMode(CapsuleMode.Takeover(thought))
    }

    fun onResumed() {
        val current = _mode.value
        if (current !is CapsuleMode.Takeover && current !is CapsuleMode.TakeoverPending) {
            Log.d(TAG, "Ignoring resume in ${current::class.simpleName}")
            return
        }
        _turnPhase.value = null
        _isAgentMidTurn.value = false
        setMode(CapsuleMode.Running("Thinking..."))
    }

    fun onUserResponseSent(callId: String): Boolean {
        val current = _mode.value
        if (current !is CapsuleMode.WaitingForInput && current !is CapsuleMode.WaitingForAction) {
            Log.d(TAG, "Ignoring user response in ${current::class.simpleName}")
            return false
        }
        val expectedCallId = when (current) {
            is CapsuleMode.WaitingForInput -> current.callId
            is CapsuleMode.WaitingForAction -> current.callId
        }
        if (expectedCallId != callId) {
            Log.d(TAG, "Ignoring user response due to callId mismatch: expected=$expectedCallId, actual=$callId")
            return false
        }
        setMode(CapsuleMode.Running("Processing response..."))
        return true
    }

    /** Mark stop as pending for immediate UI feedback. Valid only when current mode has a Stop action. */
    fun onStopRequested(): Boolean {
        val mode = _mode.value
        if (mode !is CapsuleMode.Running &&
            mode !is CapsuleMode.TakeoverPending &&
            mode !is CapsuleMode.Takeover &&
            mode !is CapsuleMode.WaitingForInput &&
            mode !is CapsuleMode.WaitingForAction &&
            mode !is CapsuleMode.WaitingForApproval
        ) {
            return false
        }
        if (_isStopPending.value) return false
        _isStopPending.value = true
        return true
    }

    fun onTaskCompleted(outcome: TaskOutcome, message: String? = null) {
        val current = _mode.value
        if (current is CapsuleMode.Hidden || current is CapsuleMode.Done || current is CapsuleMode.Error) {
            Log.d(TAG, "Ignoring task completed in ${current::class.simpleName}")
            return
        }
        _isStopPending.value = false
        val mode = when (outcome) {
            TaskOutcome.FINISHED -> {
                val completionMessage = message?.takeIf { it.isNotBlank() } ?: "Task completed"
                CapsuleMode.Done(completionMessage)
            }
            TaskOutcome.USER_STOPPED -> CapsuleMode.Done("Stopped")
            TaskOutcome.ERROR -> CapsuleMode.Error(
                message?.takeIf { it.isNotBlank() }?.let(::compactThought) ?: "Error occurred"
            )
        }
        setMode(mode)
    }

    fun onSessionEnded(reason: SessionEndReason) {
        _isStopPending.value = false
        when (reason) {
            SessionEndReason.USER_STOPPED,
            SessionEndReason.INTERRUPTED,
            SessionEndReason.IDLE_TIMEOUT -> {
                if (hasActiveTask) setMode(CapsuleMode.Done("Stopped"))
            }
        }
    }

    fun onDismissError() {
        if (_mode.value !is CapsuleMode.Error) return
        _isStopPending.value = false
        setMode(CapsuleMode.Hidden)
    }

    private fun setMode(new: CapsuleMode) {
        previousMode = _mode.value
        _mode.value = new
    }
}
