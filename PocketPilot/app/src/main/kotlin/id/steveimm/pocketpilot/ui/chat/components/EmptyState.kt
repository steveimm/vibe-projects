package id.steveimm.pocketpilot.ui.chat.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Contacts
import androidx.compose.material.icons.rounded.PhoneAndroid
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.composables.icons.lucide.ArrowRight
import com.composables.icons.lucide.Lucide
import id.steveimm.pocketpilot.ui.common.PilotMark

private data class Suggestion(val title: String, val detail: String, val prompt: String, val icon: ImageVector)

private val suggestions = listOf(
    Suggestion("Open an app", "Get where you need to go", "Open Android Settings", Icons.Rounded.PhoneAndroid),
    Suggestion("Find a contact", "Look someone up on your phone", "Find a contact named ", Icons.Rounded.Contacts),
    Suggestion("Change a setting", "Work through your phone's settings", "Help me change a setting on my phone.", Icons.Rounded.Tune),
)

@Composable
fun EmptyState(onSuggestionClick: (String) -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Surface(shape = MaterialTheme.shapes.extraLarge, color = MaterialTheme.colorScheme.primaryContainer) {
            Box(Modifier.size(76.dp), contentAlignment = Alignment.Center) { PilotMark(size = 40.dp) }
        }
        Spacer(Modifier.height(8.dp))
        Text("What would you\nlike to do?", style = MaterialTheme.typography.displaySmall,
            color = MaterialTheme.colorScheme.onBackground)
        Text("Describe a task, or start with an idea below.", style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(8.dp))
        suggestions.forEach { suggestion ->
            Surface(
                onClick = { onSuggestionClick(suggestion.prompt) },
                shape = MaterialTheme.shapes.large,
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    Icon(suggestion.icon, null, Modifier.size(22.dp), tint = MaterialTheme.colorScheme.primary)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(suggestion.title, style = MaterialTheme.typography.titleMedium)
                        Text(suggestion.detail, style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Icon(Lucide.ArrowRight, null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        Text("Suggestions fill the message box so you can edit before sending.",
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp, bottom = 8.dp))
    }
}
