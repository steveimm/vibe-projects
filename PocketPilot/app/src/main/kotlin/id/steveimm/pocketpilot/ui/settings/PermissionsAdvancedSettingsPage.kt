package id.steveimm.pocketpilot.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BugReport
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Storage
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.ui.theme.DetailPageHeader
import id.steveimm.pocketpilot.ui.theme.pocketPilot
import kotlinx.coroutines.launch

@Composable
internal fun PermissionsAdvancedSettingsPage(
    isAccessibilityEnabled: Boolean,
    isOverlayEnabled: Boolean,
    onAccessibilityClick: () -> Unit,
    onOverlayClick: () -> Unit,
    debugMode: Boolean,
    onDebugModeChange: (Boolean) -> Unit,
    traceEnabled: Boolean,
    onTraceEnabledChange: (Boolean) -> Unit,
    onClearTraces: suspend () -> Result<Unit>,
    onClearHistory: suspend () -> Result<Unit>,
    onBack: () -> Unit,
    onClose: () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        DetailPageHeader(title = "Permissions & diagnostics", onBack = onBack, onClose = onClose)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MaterialTheme.pocketPilot.spacing.lg)
        ) {
            SettingsSection(title = "Permissions") {
                Column(verticalArrangement = Arrangement.spacedBy(MaterialTheme.pocketPilot.spacing.md)) {
                    SettingsRow(
                        icon = Icons.Outlined.Settings,
                        title = "Accessibility service",
                        isEnabled = isAccessibilityEnabled,
                        onClick = onAccessibilityClick
                    )
                    SettingsRow(
                        icon = Icons.Outlined.Layers,
                        title = "Overlay permission",
                        isEnabled = isOverlayEnabled,
                        onClick = onOverlayClick
                    )
                }
            }
            Spacer(modifier = Modifier.height(20.dp))
            SettingsSection(title = "Debug") {
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    shape = MaterialTheme.shapes.medium,
                    shadowElevation = MaterialTheme.pocketPilot.elevation.card,
                    border = MaterialTheme.pocketPilot.surfaceBorder,
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = MaterialTheme.pocketPilot.spacing.cardPadding, vertical = MaterialTheme.pocketPilot.spacing.md),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.BugReport,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Debug mode",
                                style = MaterialTheme.typography.bodyLarge
                            )
                            Text(
                                text = "Enable verbose logging",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = debugMode,
                            onCheckedChange = onDebugModeChange,
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = MaterialTheme.colorScheme.primary,
                                checkedTrackColor = MaterialTheme.colorScheme.primaryContainer
                            )
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(20.dp))
            DataStorageSection(
                traceEnabled = traceEnabled,
                onTraceEnabledChange = onTraceEnabledChange,
                onClearTraces = onClearTraces,
                onClearHistory = onClearHistory,
            )
            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}

private sealed interface ClearDataState {
    data object Idle : ClearDataState
    data object Clearing : ClearDataState
    data object Cleared : ClearDataState
    data class Failed(val message: String) : ClearDataState
}

@Composable
private fun DataStorageSection(
    traceEnabled: Boolean,
    onTraceEnabledChange: (Boolean) -> Unit,
    onClearTraces: suspend () -> Result<Unit>,
    onClearHistory: suspend () -> Result<Unit>,
) {
    val scope = rememberCoroutineScope()
    var traceClearState by remember { mutableStateOf<ClearDataState>(ClearDataState.Idle) }
    var sessionClearState by remember { mutableStateOf<ClearDataState>(ClearDataState.Idle) }
    var showClearTracesConfirm by remember { mutableStateOf(false) }
    var showClearSessionsConfirm by remember { mutableStateOf(false) }

    fun clearTraces() {
        if (traceClearState is ClearDataState.Clearing || sessionClearState is ClearDataState.Clearing) return
        traceClearState = ClearDataState.Clearing
        scope.launch {
            traceClearState = onClearTraces().fold(
                onSuccess = { ClearDataState.Cleared },
                onFailure = { ClearDataState.Failed("Could not clear traces and screenshots. Try again.") },
            )
        }
    }

    fun clearSessions() {
        if (traceClearState is ClearDataState.Clearing || sessionClearState is ClearDataState.Clearing) return
        sessionClearState = ClearDataState.Clearing
        scope.launch {
            sessionClearState = onClearHistory().fold(
                onSuccess = { ClearDataState.Cleared },
                onFailure = { ClearDataState.Failed("Could not clear chat history. Try again.") },
            )
        }
    }

    if (showClearTracesConfirm) {
        AlertDialog(
            onDismissRequest = { showClearTracesConfirm = false },
            title = { Text("Clear traces") },
            text = { Text("This stops the current task and permanently deletes recorded traces and debug screenshots.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showClearTracesConfirm = false
                        clearTraces()
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) { Text("Clear") }
            },
            dismissButton = {
                TextButton(onClick = { showClearTracesConfirm = false }) { Text("Cancel") }
            }
        )
    }

    if (showClearSessionsConfirm) {
        AlertDialog(
            onDismissRequest = { showClearSessionsConfirm = false },
            title = { Text("Clear chat history") },
            text = { Text("This stops the current task and permanently deletes all saved chats, including the current conversation.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showClearSessionsConfirm = false
                        clearSessions()
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) { Text("Clear") }
            },
            dismissButton = {
                TextButton(onClick = { showClearSessionsConfirm = false }) { Text("Cancel") }
            }
        )
    }

    SettingsSection(title = "Data and storage") {
        Column(verticalArrangement = Arrangement.spacedBy(MaterialTheme.pocketPilot.spacing.md)) {
            // Trace toggle
            Surface(
                modifier = Modifier.fillMaxWidth(),
                color = MaterialTheme.colorScheme.surfaceVariant,
                shape = MaterialTheme.shapes.medium,
                shadowElevation = MaterialTheme.pocketPilot.elevation.card,
                border = MaterialTheme.pocketPilot.surfaceBorder,
            ) {
                Column(modifier = Modifier.padding(horizontal = MaterialTheme.pocketPilot.spacing.cardPadding, vertical = MaterialTheme.pocketPilot.spacing.md)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Outlined.Storage,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Session traces",
                                style = MaterialTheme.typography.bodyLarge
                            )
                            Text(
                                text = "Save step-by-step session logs",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = traceEnabled,
                            onCheckedChange = onTraceEnabledChange,
                            modifier = Modifier.testTag("qa-session-traces-switch"),
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = MaterialTheme.colorScheme.primary,
                                checkedTrackColor = MaterialTheme.colorScheme.primaryContainer
                            )
                        )
                    }
                    if (traceEnabled) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Surface(
                            color = MaterialTheme.colorScheme.errorContainer,
                            shape = MaterialTheme.shapes.small
                        ) {
                            Text(
                                text = "Includes screenshots and inputs.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onErrorContainer,
                                modifier = Modifier.padding(horizontal = MaterialTheme.pocketPilot.spacing.md, vertical = MaterialTheme.pocketPilot.spacing.sm)
                            )
                        }
                    }
                }
            }

            // Clear traces button
            ClearDataButton(
                label = clearDataButtonLabel(traceClearState, idle = "Clear traces", clearing = "Clearing traces", cleared = "Traces cleared"),
                enabled = traceClearState !is ClearDataState.Clearing && sessionClearState !is ClearDataState.Clearing &&
                    traceClearState !is ClearDataState.Cleared,
                onClick = { showClearTracesConfirm = true }
            )
            ClearFailureAlert(state = traceClearState, onRetry = { clearTraces() })

            // Clear session history button
            ClearDataButton(
                label = clearDataButtonLabel(sessionClearState, idle = "Clear chat history", clearing = "Clearing chats", cleared = "Chats cleared"),
                enabled = traceClearState !is ClearDataState.Clearing && sessionClearState !is ClearDataState.Clearing &&
                    sessionClearState !is ClearDataState.Cleared,
                onClick = { showClearSessionsConfirm = true }
            )
            ClearFailureAlert(state = sessionClearState, onRetry = { clearSessions() })
        }
    }
}

private fun clearDataButtonLabel(
    state: ClearDataState,
    idle: String,
    clearing: String,
    cleared: String,
): String = when (state) {
    ClearDataState.Idle,
    is ClearDataState.Failed -> idle
    ClearDataState.Clearing -> "$clearing..."
    ClearDataState.Cleared -> cleared
}

@Composable
private fun ClearFailureAlert(state: ClearDataState, onRetry: () -> Unit) {
    val failed = state as? ClearDataState.Failed ?: return
    SettingsAlertCard(
        message = failed.message,
        tone = AlertTone.Error,
        action = {
            TextButton(onClick = onRetry) {
                Text("Retry")
            }
        },
    )
}

@Composable
private fun ClearDataButton(
    label: String,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.errorContainer,
            contentColor = MaterialTheme.colorScheme.onErrorContainer,
            disabledContainerColor = MaterialTheme.colorScheme.surfaceVariant,
            disabledContentColor = MaterialTheme.colorScheme.onSurfaceVariant
        )
    ) {
        Icon(
            imageVector = Icons.Outlined.DeleteOutline,
            contentDescription = null,
            modifier = Modifier.size(18.dp)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(text = label, style = MaterialTheme.typography.labelLarge)
    }
}
