package id.steveimm.pocketpilot.ui.capsule.surface

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.PanTool
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.StopCircle
import androidx.compose.material3.ButtonColors
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.protocol.ApprovalDecision
import id.steveimm.pocketpilot.protocol.ApprovalScope
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleRenderSpec
import id.steveimm.pocketpilot.ui.theme.pocketPilot

/** CapsuleControlBar — the row beneath the status line / detail body. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun CapsuleControlBar(
    spec: CapsuleRenderSpec,
    mode: CapsuleMode,
    onTakeover: () -> Unit,
    onResume: () -> Unit,
    onStop: () -> Unit,
    onDone: (String) -> Unit,
    onApprovalResponse: (String, ApprovalDecision, ApprovalScope, String) -> Unit,
) {
    val buttons = spec.buttons
    val modifier = Modifier.fillMaxWidth()
    val actionModifier = Modifier.minimumInteractiveComponentSize()
    val spacing = MaterialTheme.pocketPilot.spacing.sm
    val actionButtons: @Composable () -> Unit = {
        buttons.primary?.let { btn ->
            FilledTonalButton(
                onClick = {
                    when (mode) {
                        is CapsuleMode.Running -> onTakeover()
                        is CapsuleMode.Takeover -> onResume()
                        is CapsuleMode.WaitingForAction -> onDone(mode.callId)
                        is CapsuleMode.WaitingForApproval -> onApprovalResponse(
                            mode.callId, ApprovalDecision.APPROVED, ApprovalScope.ALWAYS, mode.packageName,
                        )
                        else -> {}
                    }
                },
                modifier = actionModifier,
                enabled = btn.enabled,
                shape = MaterialTheme.shapes.large,
                colors = primaryButtonColors(),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
            ) {
                Icon(
                    imageVector = primaryIconForMode(mode),
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(6.dp))
                Text(text = btn.text, style = MaterialTheme.typography.labelLarge)
            }
        }

        buttons.secondary?.let { btn ->
            if (mode is CapsuleMode.WaitingForApproval) {
                ApprovalScopeButton(
                    btn = btn,
                    mode = mode,
                    scope = ApprovalScope.SESSION,
                    modifier = actionModifier,
                    onApprovalResponse = onApprovalResponse,
                )
            }
        }

        buttons.stop?.let { btn ->
            OutlinedButton(
                onClick = {
                    when (mode) {
                        is CapsuleMode.WaitingForApproval -> onApprovalResponse(
                            mode.callId, ApprovalDecision.DENIED, ApprovalScope.SESSION, mode.packageName,
                        )
                        else -> onStop()
                    }
                },
                modifier = actionModifier,
                enabled = btn.enabled,
                shape = MaterialTheme.shapes.large,
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.error),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
            ) {
                Icon(
                    imageVector = stopIconForMode(mode),
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.error,
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    text = btn.text,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
    FlowRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(spacing),
        verticalArrangement = Arrangement.spacedBy(spacing),
    ) { actionButtons() }
}

@Composable
private fun primaryButtonColors(): ButtonColors {
    val colorScheme = MaterialTheme.colorScheme
    return ButtonDefaults.filledTonalButtonColors(
        containerColor = colorScheme.primaryContainer,
        contentColor = colorScheme.onPrimaryContainer,
    )
}

private fun primaryIconForMode(mode: CapsuleMode): ImageVector = when (mode) {
    is CapsuleMode.Running -> Icons.Rounded.PanTool
    is CapsuleMode.Takeover -> Icons.Rounded.PlayArrow
    is CapsuleMode.WaitingForAction -> Icons.Rounded.CheckCircle
    is CapsuleMode.WaitingForApproval -> Icons.Rounded.Check
    else -> Icons.Rounded.PanTool
}

private fun stopIconForMode(mode: CapsuleMode): ImageVector = when (mode) {
    is CapsuleMode.Error -> Icons.Rounded.Close
    is CapsuleMode.WaitingForApproval -> Icons.Rounded.Close
    else -> Icons.Rounded.StopCircle
}

@Composable
private fun ApprovalScopeButton(
    btn: CapsuleRenderSpec.ButtonSpec,
    mode: CapsuleMode.WaitingForApproval,
    scope: ApprovalScope,
    modifier: Modifier = Modifier,
    onApprovalResponse: (String, ApprovalDecision, ApprovalScope, String) -> Unit,
) {
    FilledTonalButton(
        onClick = { onApprovalResponse(mode.callId, ApprovalDecision.APPROVED, scope, mode.packageName) },
        modifier = modifier,
        enabled = btn.enabled,
        shape = MaterialTheme.shapes.large,
        colors = ButtonDefaults.filledTonalButtonColors(
            containerColor = MaterialTheme.colorScheme.secondaryContainer,
            contentColor = MaterialTheme.colorScheme.onSecondaryContainer,
        ),
        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
    ) {
        Icon(Icons.Rounded.Check, null, Modifier.size(16.dp))
        Spacer(Modifier.width(6.dp))
        Text(text = btn.text, style = MaterialTheme.typography.labelLarge)
    }
}
