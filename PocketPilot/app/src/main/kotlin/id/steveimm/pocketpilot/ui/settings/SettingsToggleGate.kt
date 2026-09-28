package id.steveimm.pocketpilot.ui.settings

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import id.steveimm.pocketpilot.platform.virtualdisplay.PermissionRequestResult
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal enum class ShizukuPermissionFailure { Unavailable, Denied }

internal suspend fun requireShizukuPermission(
    isAvailable: suspend () -> Boolean,
    hasPermission: suspend () -> Boolean,
    requestPermission: suspend () -> PermissionRequestResult,
): ShizukuPermissionFailure? {
    if (!isAvailable()) return ShizukuPermissionFailure.Unavailable
    if (hasPermission()) return null

    return when (requestPermission()) {
        PermissionRequestResult.Granted -> if (hasPermission()) null else ShizukuPermissionFailure.Denied
        PermissionRequestResult.Denied -> ShizukuPermissionFailure.Denied
        PermissionRequestResult.Error -> ShizukuPermissionFailure.Unavailable
    }
}

internal open class SettingsToggleGate<Failure>(
    private val scope: CoroutineScope,
    private val onPersist: (Boolean) -> Unit,
    private val gate: suspend () -> Failure?,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    var pending by mutableStateOf(false)
        private set
    var error by mutableStateOf<Failure?>(null)
        private set
    private var attempt: Job? = null

    fun setEnabled(value: Boolean) {
        error = null
        if (!value) {
            attempt?.cancel()
            attempt = null
            pending = false
            onPersist(false)
            return
        }
        if (pending) return

        pending = true
        attempt = scope.launch(start = CoroutineStart.LAZY) {
            try {
                val result = withContext(ioDispatcher) { gate() }
                coroutineContext.ensureActive()
                if (result == null) onPersist(true) else error = result
            } finally {
                // An older cancelled attempt must not reset a newer attempt's pending state.
                if (attempt == coroutineContext[Job]) pending = false
            }
        }
        attempt?.start()
    }

    fun clearError() {
        error = null
    }
}
