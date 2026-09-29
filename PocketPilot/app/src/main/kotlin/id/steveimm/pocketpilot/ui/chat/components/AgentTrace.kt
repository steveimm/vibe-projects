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
import androidx.compose.material3.TextButton
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.composables.icons.lucide.ArrowRight
import com.composables.icons.lucide.Ban
import com.composables.icons.lucide.Check
import com.composables.icons.lucide.LoaderCircle
import com.composables.icons.lucide.Lucide
import com.composables.icons.lucide.X
import id.steveimm.pocketpilot.ui.chat.model.ActionCardData
import id.steveimm.pocketpilot.ui.chat.model.ActionState
import id.steveimm.pocketpilot.ui.chat.model.AgentMessageState
import id.steveimm.pocketpilot.ui.chat.model.ContentBlock
import id.steveimm.pocketpilot.ui.theme.pocketPilot

@Composable
internal fun ExpandedTrace(blocks: List<ContentBlock>, state: AgentMessageState) {
    val spacing = MaterialTheme.pocketPilot.spacing
    val lastTextIndex = blocks.indexOfLast { it is ContentBlock.Text }
    Column(verticalArrangement = Arrangement.spacedBy(spacing.md), modifier = Modifier.fillMaxWidth()) {
        blocks.forEachIndexed { index, block ->
            when (block) {
                is ContentBlock.Reasoning -> ReasoningBlock(block.text)
                is ContentBlock.Action -> ActionRow(block.data)
                is ContentBlock.Text -> StreamingText(
                    text = block.text,
                    isStreaming = state == AgentMessageState.Streaming && index == lastTextIndex,
                    textColor = MaterialTheme.colorScheme.onSurface,
                )
                is ContentBlock.FinalText -> Unit
            }
        }
    }
}

@Composable
private fun ReasoningBlock(text: String) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    Column {
        TextButton(onClick = { expanded = !expanded }) {
            Text(if (expanded) "Hide model reasoning" else "Show model reasoning")
        }
        if (expanded) SelectionContainer { Text(text, style = MaterialTheme.typography.bodyMedium) }
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
        ActionState.Skipped -> MaterialTheme.pocketPilot.inkFaint
        ActionState.Proposed, ActionState.Executing -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    Column(modifier = modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Icon(
                imageVector = Lucide.ArrowRight,
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = MaterialTheme.pocketPilot.inkFaint,
            )
            Spacer(Modifier.width(spacing.sm))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = formatToolCall(data),
                    style = MaterialTheme.pocketPilot.monoSmall,
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
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = spacing.xs),
                color = MaterialTheme.colorScheme.surfaceVariant,
                shape = MaterialTheme.shapes.small,
            ) {
                Text(
                    text = expanded,
                    style = MaterialTheme.pocketPilot.monoSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(spacing.sm),
                )
            }
        }
    }
}

private fun formatToolCall(data: ActionCardData): String {
    val args = data.description.takeIf { it.isNotBlank() } ?: ""
    return "${data.toolName}($args)"
}
