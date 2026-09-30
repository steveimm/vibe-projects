package id.steveimm.pocketpilot.ui.settings

import id.steveimm.pocketpilot.ui.theme.pocketPilot
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape

@Composable
internal fun SettingsCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    shape: Shape = MaterialTheme.shapes.medium,
    color: Color = MaterialTheme.colorScheme.surface,
    contentPadding: PaddingValues = PaddingValues(
        horizontal = MaterialTheme.pocketPilot.spacing.cardPadding,
        vertical = MaterialTheme.pocketPilot.spacing.md,
    ),
    content: @Composable ColumnScope.() -> Unit,
) {
    val base = modifier.fillMaxWidth().clip(shape)
    val interactive = if (onClick != null) base.clickable(onClick = onClick) else base
    Surface(
        modifier = interactive,
        color = color,
        shape = shape,
    ) {
        Column(modifier = Modifier.padding(contentPadding), content = content)
    }
}
