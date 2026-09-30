package id.steveimm.pocketpilot.ui.chat.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Text
import id.steveimm.pocketpilot.ui.settings.SettingsAlertCard
import id.steveimm.pocketpilot.ui.settings.AlertTone
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.IntSize
import id.steveimm.pocketpilot.ui.chat.model.AgentMessageState
import id.steveimm.pocketpilot.ui.chat.model.ChatMessage
import id.steveimm.pocketpilot.ui.chat.model.ContentBlock
import id.steveimm.pocketpilot.ui.chat.model.RowState
import id.steveimm.pocketpilot.ui.theme.PocketPilotMotion
import id.steveimm.pocketpilot.ui.theme.pocketPilot

@Composable
internal fun AgentRow(
    message: ChatMessage.Agent,
    onOpenApp: (String) -> Unit,
    onInspect: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val spacing = MaterialTheme.pocketPilot.spacing
    val finalText = message.contentBlocks.filterIsInstance<ContentBlock.FinalText>().lastOrNull()
    val preview = if (finalText == null) message.contentBlocks.lastOrNull() as? ContentBlock.Text else null
    val traceBlocks = message.contentBlocks.filter { it !is ContentBlock.FinalText && it !== preview }
    var expanded by remember(message.id) { mutableStateOf(false) }
    val rowDescription = when (message.rowState) {
        RowState.Live -> "live"
        RowState.Waiting -> "waiting"
        RowState.Complete -> if (expanded) "expanded" else "collapsed"
        RowState.Stopped -> "stopped"
        RowState.Error -> "error"
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("qa-agent-bubble")
            .semantics { stateDescription = rowDescription },
        verticalArrangement = Arrangement.spacedBy(spacing.sm),
    ) {
        if (message.state == AgentMessageState.Thinking && message.contentBlocks.isEmpty()) {
            ThinkingIndicator()
            return@Column
        }

        if (traceBlocks.isNotEmpty()) {
            CollapsePill(
                summary = outcomeFooter(message),
                active = message.rowState == RowState.Live,
                expanded = expanded,
                onToggle = {
                    if (!expanded) onInspect()
                    expanded = !expanded
                },
            )
            val rowTween = tween<IntSize>(PocketPilotMotion.RowExpand, easing = PocketPilotMotion.EaseInOutSine)
            val fadeTween = tween<Float>(PocketPilotMotion.RowExpand, easing = PocketPilotMotion.EaseInOutSine)
            AnimatedVisibility(
                visible = expanded,
                enter = expandVertically(animationSpec = rowTween) + fadeIn(animationSpec = fadeTween),
                exit = shrinkVertically(animationSpec = rowTween) + fadeOut(animationSpec = fadeTween),
            ) {
                ExpandedTrace(traceBlocks, message.state)
            }
        }

        if (preview != null) {
            if (message.rowState == RowState.Error) {
                SettingsAlertCard(message = preview.text, tone = AlertTone.Error)
            } else {
                StreamingText(
                    text = preview.text,
                    isStreaming = message.state == AgentMessageState.Streaming,
                    textColor = MaterialTheme.colorScheme.onSurface,
                )
            }
        }
        if (message.rowState == RowState.Stopped) {
            Text("Stopped", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        if (finalText != null) {
            FinalAnswer(text = finalText.text)
        }

        if (message.rowState == RowState.Complete && message.handoff != null) {
            CompletionHandoffCtaRow(
                handoff = message.handoff,
                onOpenApp = onOpenApp,
            )
        }
    }
}

@Composable
private fun FinalAnswer(text: String) {
    SelectionContainer(modifier = Modifier.fillMaxWidth().testTag("qa-final-answer")) {
        ChatMarkdown(text)
    }
}
