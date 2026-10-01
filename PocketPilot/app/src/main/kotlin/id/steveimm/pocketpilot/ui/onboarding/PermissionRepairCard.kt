package id.steveimm.pocketpilot.ui.onboarding

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.onboarding.PermissionStateMonitor.PermissionRepairModel
import id.steveimm.pocketpilot.ui.theme.pocketPilot

@Composable
fun PermissionRepairCard(
    model: PermissionRepairModel,
    onFixAccessibility: () -> Unit,
    onFixOverlay: () -> Unit,
    onFixBattery: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val detail = when {
        model.accessibilityMissing -> "Enable accessibility to let PocketPilot interact with your phone."
        model.accessibilityConnecting -> "Accessibility is enabled. Waiting for Android to connect the service."
        model.overlayMissing -> "Allow display over other apps to keep task controls available."
        else -> "Allow background activity so long tasks can continue."
    }
    val action = when {
        model.accessibilityMissing || model.accessibilityConnecting -> onFixAccessibility
        model.overlayMissing -> onFixOverlay
        else -> onFixBattery
    }
    Surface(
        modifier = modifier.fillMaxWidth().padding(bottom = 8.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = MaterialTheme.shapes.medium,
        shadowElevation = MaterialTheme.pocketPilot.elevation.card,
        border = MaterialTheme.pocketPilot.surfaceBorder,
    ) {
        Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp)) {
            Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            TextButton(onClick = action) { Text("Open settings") }
        }
    }
}
