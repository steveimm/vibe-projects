package id.steveimm.pocketpilot.ui.settings

import id.steveimm.pocketpilot.browser.setup.CommandLineWriter
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

internal sealed interface BrowserScriptToggleError {
    data object ShizukuUnavailable : BrowserScriptToggleError
    data object ShizukuPermissionDenied : BrowserScriptToggleError
    data object WriteFailed : BrowserScriptToggleError
}

internal fun BrowserScriptToggleError.message(): String = when (this) {
    BrowserScriptToggleError.ShizukuUnavailable ->
        "Shizuku is not running. Start Shizuku first, then enable browser_script."
    BrowserScriptToggleError.ShizukuPermissionDenied ->
        "Permission denied. Tap to retry, or re-grant in Shizuku Manager."
    BrowserScriptToggleError.WriteFailed ->
        "Could not write Chrome's command-line file. Check Shizuku and try again."
}

internal suspend fun gateBrowserScriptEnable(
    isShizukuAvailable: suspend () -> Boolean = { ShizukuClient().isAvailable() },
    hasShizukuPermission: suspend () -> Boolean = { ShizukuClient().hasPermission() },
    requestShizukuPermission: suspend () -> PermissionRequestResult = {
        ShizukuRuntimeGateway().requestPermissionAndAwait()
    },
    ensureCommandLineWritten: suspend () -> CommandLineWriter.Outcome = {
        CommandLineWriter().ensureWritten()
    },
): BrowserScriptToggleError? {
    when (requireShizukuPermission(isShizukuAvailable, hasShizukuPermission, requestShizukuPermission)) {
        ShizukuPermissionFailure.Unavailable -> return BrowserScriptToggleError.ShizukuUnavailable
        ShizukuPermissionFailure.Denied -> return BrowserScriptToggleError.ShizukuPermissionDenied
        null -> Unit
    }
    return when (ensureCommandLineWritten()) {
        CommandLineWriter.Outcome.Failed -> BrowserScriptToggleError.WriteFailed
        CommandLineWriter.Outcome.Written,
        CommandLineWriter.Outcome.AlreadyCorrect -> null
    }
}

internal class BrowserScriptToggleGate(
    scope: CoroutineScope,
    onPersist: (Boolean) -> Unit,
    gate: suspend () -> BrowserScriptToggleError? = ::gateBrowserScriptEnable,
    ioDispatcher: kotlinx.coroutines.CoroutineDispatcher = Dispatchers.IO,
) : SettingsToggleGate<BrowserScriptToggleError>(scope, onPersist, gate, ioDispatcher)

@Composable
internal fun rememberBrowserScriptToggleGate(
    onPersist: (Boolean) -> Unit,
): BrowserScriptToggleGate {
    val scope = rememberCoroutineScope()
    val currentOnPersist by rememberUpdatedState(onPersist)
    return remember(scope) {
        BrowserScriptToggleGate(scope = scope, onPersist = { currentOnPersist(it) })
    }
}
