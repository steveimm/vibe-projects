package id.steveimm.pocketpilot.ui.chat.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.ui.chat.model.ChatMessage
import id.steveimm.pocketpilot.ui.theme.pocketPilot
import android.content.Context
import java.util.Date

/** MessageBubble — entry-point dispatcher. User vs Agent rendering lives in [UserBubble] / [AgentRow]. */
@Composable
fun MessageBubble(
    message: ChatMessage,
    onOpenApp: (String) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val screenWidth = LocalConfiguration.current.screenWidthDp.dp
    when (message) {
        is ChatMessage.User -> UserBubble(
            message = message,
            maxWidth = screenWidth * 0.85f,
            modifier = modifier,
        )
        is ChatMessage.Agent -> AgentRow(
            message = message,
            onOpenApp = onOpenApp,
            modifier = modifier,
        )
    }
}

private val UserBubbleShape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp, bottomEnd = 6.dp, bottomStart = 20.dp)

@Composable
private fun UserBubble(
    message: ChatMessage.User,
    maxWidth: Dp,
    modifier: Modifier = Modifier,
) {
    val spacing = MaterialTheme.pocketPilot.spacing
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.End,
    ) {
        Surface(
            modifier = Modifier
                .widthIn(max = maxWidth)
                .testTag("qa-user-bubble"),
            color = MaterialTheme.colorScheme.primaryContainer,
            shape = UserBubbleShape,
        ) {
            Column(
                modifier = Modifier.padding(
                    start = spacing.md,
                    end = spacing.md,
                    top = spacing.sm,
                    bottom = 6.dp,
                ),
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                SelectionContainer {
                    Text(
                        text = message.text,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                }
                Text(
                    text = formatTime(LocalContext.current, message.timestamp),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.75f),
                )
            }
        }
    }
}

// Use the platform's time format (respects user's 12/24h preference and locale).
private fun formatTime(context: Context, timestamp: Long): String =
    android.text.format.DateFormat.getTimeFormat(context).format(Date(timestamp))
