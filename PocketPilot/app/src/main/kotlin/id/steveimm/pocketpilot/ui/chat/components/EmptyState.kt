package id.steveimm.pocketpilot.ui.chat.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Contacts
import androidx.compose.material.icons.rounded.PhoneAndroid
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp

private data class Suggestion(val title: String, val prompt: String, val icon: ImageVector)

private val suggestions = listOf(
    Suggestion("Open an app", "Open Android Settings", Icons.Rounded.PhoneAndroid),
    Suggestion("Find a contact", "Find a contact named ", Icons.Rounded.Contacts),
    Suggestion("Change a setting", "Help me change a setting on my phone.", Icons.Rounded.Tune),
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun EmptyState(onSuggestionClick: (String) -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.BottomStart) {
        FlowRow(
            modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            suggestions.forEach { suggestion ->
                AssistChip(
                    onClick = { onSuggestionClick(suggestion.prompt) },
                    label = { Text(suggestion.title) },
                    leadingIcon = { Icon(suggestion.icon, null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.primary) },
                )
            }
        }
    }
}
