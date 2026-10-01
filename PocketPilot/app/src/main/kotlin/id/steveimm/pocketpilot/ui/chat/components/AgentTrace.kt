package id.steveimm.pocketpilot.ui.chat.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.composables.icons.lucide.ArrowRight
import com.composables.icons.lucide.Ban
import com.composables.icons.lucide.Check
import com.composables.icons.lucide.LoaderCircle
import com.composables.icons.lucide.Lucide
import com.composables.icons.lucide.X
import id.steveimm.pocketpilot.ui.chat.model.ActionCardData
import id.steveimm.pocketpilot.ui.chat.model.ActionState
import id.steveimm.pocketpilot.ui.chat.model.ContentBlock
import id.steveimm.pocketpilot.ui.theme.pocketPilot

@Composable
internal fun ExpandedTrace(blocks: List<ContentBlock>, modifier: Modifier = Modifier) {
    val spacing = MaterialTheme.pocketPilot.spacing
    Column(verticalArrangement = Arrangement.spacedBy(spacing.md), modifier = modifier.fillMaxWidth()) {
        blocks.forEach { block ->
            when (block) {
                is ContentBlock.Reasoning -> ReasoningBlock(block.text)
                is ContentBlock.Action -> ActionRow(block.data)
                is ContentBlock.Text -> Column(verticalArrangement = Arrangement.spacedBy(spacing.xs)) {
                    Text("Update", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(block.text.trim('\n', '\r'), style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                is ContentBlock.FinalText -> Unit
            }
        }
    }
}

@Composable
private fun ReasoningBlock(text: String) {
    SelectionContainer {
        Text(text.trim('\n', '\r'), style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** A tool action and its execution result. */
@Composable
internal fun ActionRow(
    data: ActionCardData,
    modifier: Modifier = Modifier,
) {
    val spacing = MaterialTheme.pocketPilot.spacing
    val statusIcon = when (data.state) {
        ActionState.Proposed, ActionState.Executing -> Lucide.LoaderCircle
        ActionState.Success -> Lucide.Check
        ActionState.Failed -> Lucide.X
        ActionState.Skipped -> Lucide.Ban
    }
    val statusDescription = when (data.state) {
        ActionState.Proposed -> "Proposed"
        ActionState.Executing -> "Executing"
        ActionState.Success -> "Success"
        ActionState.Failed -> "Failed"
        ActionState.Skipped -> "Skipped"
    }
    val statusColor = when (data.state) {
        ActionState.Success -> MaterialTheme.colorScheme.secondary
        ActionState.Failed -> MaterialTheme.colorScheme.error
        ActionState.Skipped -> MaterialTheme.pocketPilot.mutedText
        ActionState.Proposed, ActionState.Executing -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    Surface(
        modifier = modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = MaterialTheme.shapes.small,
    ) {
        Column(modifier = Modifier.padding(spacing.sm)) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Icon(
                    imageVector = Lucide.ArrowRight,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = MaterialTheme.pocketPilot.mutedText,
                )
                Spacer(Modifier.width(spacing.sm))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = data.description.ifBlank { data.toolName },
                        style = MaterialTheme.pocketPilot.monoBody,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    val subtitle = data.resultSummary
                        ?: data.description.takeIf { it.isNotEmpty() && data.state != ActionState.Success }
                    if (!subtitle.isNullOrBlank() && subtitle != data.description) {
                        Text(
                            text = subtitle,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Spacer(Modifier.width(spacing.sm))
                Icon(
                    imageVector = statusIcon,
                    contentDescription = statusDescription,
                    modifier = Modifier.size(14.dp),
                    tint = statusColor,
                )
            }
            val expanded = data.expandedContent
            if (!expanded.isNullOrBlank()) {
                Text(
                    text = expanded,
                    style = MaterialTheme.pocketPilot.monoSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = spacing.xs),
                )
            }
        }
    }
}
