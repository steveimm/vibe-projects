package id.steveimm.pocketpilot.ui.theme

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

@Composable
fun ScreenHeader(
    title: String,
    modifier: Modifier = Modifier,
    leadingSlot: @Composable RowScope.() -> Unit = {},
    rightSlot: @Composable RowScope.() -> Unit = {},
    trailingSlot: @Composable RowScope.() -> Unit = {},
) {
    Row(modifier.fillMaxWidth().heightIn(min = 64.dp).padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        leadingSlot()
        Spacer(Modifier.width(12.dp))
        Text(title, Modifier.weight(1f), style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onSurface, maxLines = 1, overflow = TextOverflow.Ellipsis)
        rightSlot()
        trailingSlot()
    }
}

@Composable
fun RootPageHeader(title: String, onClose: (() -> Unit)? = null, modifier: Modifier = Modifier) {
    ScreenHeader(title, modifier, trailingSlot = {
        if (onClose != null) IconButton(onClick = onClose) { Icon(Icons.Rounded.Close, "Close") }
    })
}

@Composable
fun DetailPageHeader(title: String, onBack: () -> Unit, onClose: () -> Unit, modifier: Modifier = Modifier) {
    ScreenHeader(title, modifier, leadingSlot = {
        IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "Back") }
    }, trailingSlot = {
        IconButton(onClick = onClose) { Icon(Icons.Rounded.Close, "Close") }
    })
}

@Composable
fun SectionHeader(text: String, modifier: Modifier = Modifier) {
    Text(text, modifier.padding(top = 16.dp, bottom = 8.dp), style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant)
}
