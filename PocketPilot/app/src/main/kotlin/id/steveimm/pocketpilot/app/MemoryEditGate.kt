package id.steveimm.pocketpilot.app

import id.steveimm.pocketpilot.protocol.SessionState
import id.steveimm.pocketpilot.session.SessionCoordinator
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn

/** Single-writer guard for memory file edits from Settings. */
class MemoryEditGate(
    private val sessionCoordinator: SessionCoordinator,
    scope: CoroutineScope,
) {
    val memoryEditLocked: StateFlow<Boolean> =
        sessionCoordinator.currentSessionState
            .map { state -> state != null && state != SessionState.Shutdown }
            .stateIn(scope, SharingStarted.Eagerly, initialValue = true)

    /** Synchronous, race-free locked check. */
    fun isLockedNow(): Boolean {
        val state = sessionCoordinator.currentSessionState.value
        return state != null && state != SessionState.Shutdown
    }
}
