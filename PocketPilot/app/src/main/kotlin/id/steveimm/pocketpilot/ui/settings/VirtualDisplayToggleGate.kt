package id.steveimm.pocketpilot.ui.settings

import id.steveimm.pocketpilot.platform.virtualdisplay.PermissionRequestResult
import id.steveimm.pocketpilot.platform.virtualdisplay.ShizukuClient
import id.steveimm.pocketpilot.platform.virtualdisplay.ShizukuRuntimeGateway
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers

internal sealed interface VirtualDisplayToggleError {
    data object ShizukuUnavailable : VirtualDisplayToggleError
    data object ShizukuPermissionDenied : VirtualDisplayToggleError
}

internal fun VirtualDisplayToggleError.message(): String = when (this) {
    VirtualDisplayToggleError.ShizukuUnavailable ->
        "Shizuku is not running. Install or start Shizuku, then turn on Virtual Display."
    VirtualDisplayToggleError.ShizukuPermissionDenied ->
        "Permission denied. Tap to retry, or grant in Shizuku Manager."
}

internal suspend fun gateVirtualDisplayEnable(
    isShizukuAvailable: suspend () -> Boolean = { ShizukuClient().isAvailable() },
    hasShizukuPermission: suspend () -> Boolean = { ShizukuClient().hasPermission() },
    requestShizukuPermission: suspend () -> PermissionRequestResult = {
        ShizukuRuntimeGateway().requestPermissionAndAwait()
    },
): VirtualDisplayToggleError? {
    when (requireShizukuPermission(isShizukuAvailable, hasShizukuPermission, requestShizukuPermission)) {
        ShizukuPermissionFailure.Unavailable -> return VirtualDisplayToggleError.ShizukuUnavailable
        ShizukuPermissionFailure.Denied -> return VirtualDisplayToggleError.ShizukuPermissionDenied
        null -> Unit
    }
    return null
}

internal class VirtualDisplayToggleGate(
    scope: CoroutineScope,
    onPersist: (Boolean) -> Unit,
    gate: suspend () -> VirtualDisplayToggleError? = ::gateVirtualDisplayEnable,
    ioDispatcher: kotlinx.coroutines.CoroutineDispatcher = Dispatchers.IO,
) : SettingsToggleGate<VirtualDisplayToggleError>(scope, onPersist, gate, ioDispatcher)

@Composable
internal fun rememberVirtualDisplayToggleGate(
    onPersist: (Boolean) -> Unit,
): VirtualDisplayToggleGate {
    val scope = rememberCoroutineScope()
    val currentOnPersist by rememberUpdatedState(onPersist)
    return remember(scope) {
        VirtualDisplayToggleGate(scope = scope, onPersist = { currentOnPersist(it) })
    }
}
