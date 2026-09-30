package id.steveimm.pocketpilot.ui.chat.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.ui.common.PilotMark
import id.steveimm.pocketpilot.ui.theme.PocketPilotMotion

@Composable
fun ThinkingIndicator(modifier: Modifier = Modifier) {
    Row(modifier.testTag("qa-thinking-indicator").semantics { liveRegion = LiveRegionMode.Polite },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        if (PocketPilotMotion.reducedMotion()) PilotMark(size = 20.dp)
        else CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
        Text("Thinking…", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
