package id.steveimm.pocketpilot.platform.virtualdisplay

import android.media.ImageReader
import android.util.Log
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Virtual-display lifecycle states. */
sealed interface VdState {
    data object Stopped : VdState
    data class Running(val displayId: Int, val imageReader: ImageReader) : VdState
    data class Draining(val displayId: Int, val imageReader: ImageReader) : VdState
    data class Broken(
        val reason: String,
        val displayId: Int,
        val imageReader: ImageReader
    ) : VdState
}

/** Serializes virtual-display lifecycle transitions and protects in-flight operational calls. */
internal class VdLifecycleArbiter {
    @Volatile var state: VdState = VdState.Stopped
        private set

    private val lifecycleMutex = Mutex()
    private val activeOps = AtomicInteger(0)

    companion object {
        private const val TAG = "VdLifecycleArbiter"
        private const val DRAIN_TIMEOUT_MS = 5_000L
        private const val DRAIN_POLL_MS = 5L
    }

    /** Execute a lifecycle transition under exclusive access. */
    suspend fun <T> withLifecycleTransition(
        preDrainTransform: ((VdState) -> VdState)? = null,
        block: suspend (previousState: VdState) -> T
    ): T =
        lifecycleMutex.withLock {
            val previous = state
            preDrainTransform?.let { state = it(previous) }
            drainActiveOps()
            block(previous)
        }

    /** Execute an operational call under a Running lease. */
    suspend fun <T> withRunningLease(block: suspend (VdState.Running) -> T): T {
        activeOps.incrementAndGet()
        try {
            val s = state
            if (s !is VdState.Running) throw PlatformNotRunningException(s)
            return block(s)
        } finally {
            activeOps.decrementAndGet()
        }
    }

    /** Update state. Call only from within [withLifecycleTransition]. */
    fun transitionTo(newState: VdState) {
        state = newState
    }

    /** Emergency transition to [VdState.Broken]. */
    fun markBroken(reason: String) {
        val current = state
        if (current == VdState.Stopped || current is VdState.Broken) return
        if (current is VdState.Running) {
            state = VdState.Broken(reason, current.displayId, current.imageReader)
        } else if (current is VdState.Draining) {
            state = VdState.Broken(reason, current.displayId, current.imageReader)
        } else {
            // Should not happen, but guard against unexpected states
            state = VdState.Stopped
        }
    }

    private suspend fun drainActiveOps() {
        val deadline = System.nanoTime() + DRAIN_TIMEOUT_MS * 1_000_000
        while (activeOps.get() > 0) {
            if (System.nanoTime() > deadline) {
                Log.w(TAG, "Drain timeout — ${activeOps.get()} ops still in flight, proceeding")
                break
            }
            delay(DRAIN_POLL_MS)
        }
    }
}

/** Thrown when an operational call is attempted on a non-Running platform. */
class PlatformNotRunningException(state: VdState) :
    IllegalStateException("Platform not running (${state.description})")

private val VdState.description: String
    get() = when (this) {
        VdState.Stopped -> "Stopped"
        is VdState.Running -> "Running(displayId=$displayId)"
        is VdState.Draining -> "Draining(displayId=$displayId)"
        is VdState.Broken -> "Broken: $reason"
    }
