package id.steveimm.pocketpilot.ui.chat.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Menu
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.ui.common.PilotMark

@Composable
fun ChatHeader(
    onMenuClick: () -> Unit,
    onNewChatClick: (() -> Unit)? = null,
    showNewChatButton: Boolean = true,
    modifier: Modifier = Modifier,
    modelName: String = "",
) {
    Row(modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).heightIn(min = 64.dp).padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onMenuClick) { Icon(Icons.Rounded.Menu, "Open menu") }
        Spacer(Modifier.width(4.dp))
        PilotMark(size = 26.dp)
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text("PocketPilot", style = MaterialTheme.typography.titleLarge)
            if (modelName.isNotBlank()) Text(modelName, style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (showNewChatButton && onNewChatClick != null) {
            IconButton(onClick = onNewChatClick) { Icon(Icons.Rounded.Add, "New conversation") }
        } else Spacer(Modifier.size(48.dp))
    }
}
