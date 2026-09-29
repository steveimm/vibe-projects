package id.steveimm.pocketpilot.ui.settings

import id.steveimm.pocketpilot.app.AppSettingsStore
import id.steveimm.pocketpilot.termux.NeedsSetupReason
import id.steveimm.pocketpilot.termux.TermuxBridgeManager
import id.steveimm.pocketpilot.termux.TermuxBridgeStatus
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

private const val TERMUX_INSTALL_URL = "https://f-droid.org/packages/com.termux/"
private const val TERMUX_PACKAGE = "com.termux"

@Composable
internal fun ToolsSection() {
    SettingsSection(title = "Tools") { TermuxShellSettingsRow() }
}

@Composable
private fun TermuxShellSettingsRow() {
    val context = LocalContext.current
    val appContext = context.applicationContext
    val activity = remember(context) { context.findActivity() }
    val manager = remember(appContext) { TermuxBridgeManager.get(appContext) }
    val settingsStore = remember(appContext) { AppSettingsStore(appContext) }
    val bridgeStatus by manager.state.collectAsStateWithLifecycle()
    val termuxShellEnabled by settingsStore.termuxShellEnabled.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    // Preview contexts have no Activity. Runtime permission requests are available only with a ComponentActivity.
    val permissionGate = activity?.let {
        rememberRunCommandPermissionGate(activity = it) { granted ->
            if (granted) {
                scope.launch(Dispatchers.IO) { manager.setup() }
            }
        }
    }

    LaunchedEffect(manager, termuxShellEnabled) {
        if (termuxShellEnabled) {
            val detected = manager.detectInstalled()
            if (detected !is TermuxBridgeStatus.NotInstalled) {
                manager.healthCheck()
            }
        }
    }

    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner, manager, termuxShellEnabled) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME && termuxShellEnabled) {
                scope.launch {
                    val detected = manager.detectInstalled()
                    if (detected !is TermuxBridgeStatus.NotInstalled) {
                        manager.healthCheck()
                    }
                }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val displayedStatus = if (termuxShellEnabled) bridgeStatus else TermuxBridgeStatus.Disabled
    val permissionDisposition = permissionGate?.disposition()
    val statusUi = termuxStatusUi(
        state = bridgeStatus,
        permissionDisposition = permissionDisposition,
        enabledPref = termuxShellEnabled,
    )

    val rowAction: (() -> Unit)? =
        when (displayedStatus) {
            TermuxBridgeStatus.NotInstalled -> {
                { context.openTermuxInstallPage() }
            }
            is TermuxBridgeStatus.NeedsSetup -> {
                when (displayedStatus.reason) {
                    NeedsSetupReason.TERMUX_RUN_COMMAND_UNAVAILABLE -> {
                        { context.openTermuxInstallPage() }
                    }
                    NeedsSetupReason.TERMUX_NOT_RUNNING -> {
                        { context.launchTermux() }
                    }
                    NeedsSetupReason.PERMISSION_MISSING -> permissionRowAction(
                        gate = permissionGate,
                        runSetup = { scope.launch(Dispatchers.IO) { manager.setup() } },
                    )
                    else -> {
                        { scope.launch(Dispatchers.IO) { manager.setup() } }
                    }
                }
            }
            TermuxBridgeStatus.Ready -> {
                { scope.launch(Dispatchers.IO) { manager.restart() } }
            }
            TermuxBridgeStatus.SetupInProgress,
            TermuxBridgeStatus.Disabled -> null
        }

    val rowClickLabel = when (displayedStatus) {
        TermuxBridgeStatus.NotInstalled -> "Install Termux"
        is TermuxBridgeStatus.NeedsSetup -> "Fix Termux setup"
        TermuxBridgeStatus.Ready -> "Restart Termux bridge"
        else -> null
    }

    ToolSettingsCard(
        title = "Termux Shell",
        status = statusUi,
        switchChecked = termuxShellEnabled,
        onSwitchChange = { enabled ->
            scope.launch {
                settingsStore.setTermuxShellEnabled(enabled)
                if (enabled) {
                    // Proactively request the dangerous permission so the user sees the system dialog the first time they enable the
                    // toggle, instead of having to enable → see "RUN_COMMAND missing" → tap the row → see the dialog.
                    when (permissionGate?.disposition()) {
                        RunCommandPermissionDisposition.Request ->
                            permissionGate.requestPermission()
                        RunCommandPermissionDisposition.OpenAppSettings ->
                            permissionGate.openAppSettings()
                        RunCommandPermissionDisposition.Granted, null -> Unit
                    }
                }
            }
        },
        onRowClick = rowAction,
        onRowClickLabel = rowClickLabel,
    )
}

/** Build the tap handler for the PERMISSION_MISSING reason. */
private fun permissionRowAction(
    gate: RunCommandPermissionGate?,
    runSetup: () -> Unit,
): () -> Unit = {
    when (gate?.disposition()) {
        RunCommandPermissionDisposition.Granted, null -> runSetup()
        RunCommandPermissionDisposition.Request -> gate.requestPermission()
        RunCommandPermissionDisposition.OpenAppSettings -> gate.openAppSettings()
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

private fun android.content.Context.openTermuxInstallPage() {
    try {
        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(TERMUX_INSTALL_URL)))
    } catch (_: ActivityNotFoundException) {
        Toast.makeText(this, "Unable to open Termux install page", Toast.LENGTH_SHORT).show()
    }
}

private fun android.content.Context.launchTermux() {
    val intent = packageManager.getLaunchIntentForPackage(TERMUX_PACKAGE)
    if (intent == null) {
        Toast.makeText(this, "Termux is not installed", Toast.LENGTH_SHORT).show()
        return
    }
    try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    } catch (_: ActivityNotFoundException) {
        Toast.makeText(this, "Unable to launch Termux", Toast.LENGTH_SHORT).show()
    }
}
