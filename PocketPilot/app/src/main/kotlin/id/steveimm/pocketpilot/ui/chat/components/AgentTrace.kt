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
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
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

/** AgentTrace — UXFB-4 ThoughtGroup layout. */

internal data class ThoughtGroup(
    val thought: ContentBlock.Thought?,
    val items: List<ContentBlock>,
)

internal fun groupTrace(blocks: List<ContentBlock>): List<ThoughtGroup> {
    val groups = mutableListOf<ThoughtGroup>()
    var thought: ContentBlock.Thought? = null
    var items = mutableListOf<ContentBlock>()
    fun flush() {
        if (thought != null || items.isNotEmpty()) {
            groups += ThoughtGroup(thought, items.toList())
        }
        thought = null
        items = mutableListOf()
    }
    for (block in blocks) {
        when (block) {
            is ContentBlock.Thought -> {
                flush()
                thought = block
            }
            is ContentBlock.Action, is ContentBlock.Text -> items += block
            is ContentBlock.FinalText -> Unit
        }
    }
    flush()
    return groups
}

@Composable
internal fun ExpandedTrace(blocks: List<ContentBlock>, state: AgentMessageState) {
    val spacing = MaterialTheme.pocketPilot.spacing
    val groups = groupTrace(blocks)
    val isStreaming = state == AgentMessageState.Streaming
    val lastTextIndex = blocks.indexOfLast { it is ContentBlock.Text }
    Column(
        verticalArrangement = Arrangement.spacedBy(spacing.md),
        modifier = Modifier.fillMaxWidth(),
    ) {
        groups.forEach { group ->
            ThoughtGroupView(
                group = group,
                isStreaming = isStreaming,
                streamingTextBlockIndex = lastTextIndex,
                allBlocks = blocks,
            )
        }
    }
}

@Composable
private fun ThoughtGroupView(
    group: ThoughtGroup,
    isStreaming: Boolean,
    streamingTextBlockIndex: Int,
    allBlocks: List<ContentBlock>,
) {
    val spacing = MaterialTheme.pocketPilot.spacing
    val ruleColor = MaterialTheme.colorScheme.tertiary
    val ruleWidthDp = 3.dp
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .drawBehind {
                drawRect(
                    color = ruleColor,
                    topLeft = Offset.Zero,
                    size = Size(ruleWidthDp.toPx(), size.height),
                )
            }
            .padding(start = ruleWidthDp + spacing.md),
        verticalArrangement = Arrangement.spacedBy(spacing.xs),
    ) {
        group.thought?.let { ThoughtHeader(it.text) }
        group.items.forEach { item ->
            when (item) {
                is ContentBlock.Action -> ActionRow(
                    data = item.data,
                    modifier = Modifier.padding(start = spacing.lg),
                )
                is ContentBlock.Text -> {
                    val streamingTail =
                        isStreaming && allBlocks.indexOf(item) == streamingTextBlockIndex
                    if (streamingTail) {
                        StreamingText(
                            text = item.text,
                            isStreaming = true,
                            textColor = MaterialTheme.colorScheme.onSurface,
                        )
                    } else if (item.text.isNotEmpty()) {
                        SelectionContainer(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                text = item.text,
                                style = MaterialTheme.typography.bodyLarge,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                        }
                    }
                }
                else -> Unit
            }
        }
    }
}

@Composable
private fun ThoughtHeader(text: String) {
    SelectionContainer(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

/** ActionRow — inline trace row for an action. UXFB-4: monoSmall + onSurfaceVariant inside a ThoughtGroup; status glyph stays
 * right-aligned. Caller supplies the group's start indent via [modifier]. */
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
