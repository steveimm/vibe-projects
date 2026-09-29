package id.steveimm.pocketpilot.ui.chat.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.Placeholder
import androidx.compose.ui.text.PlaceholderVerticalAlign
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.unit.em
import id.steveimm.pocketpilot.ui.theme.PocketPilotMotion
import id.steveimm.pocketpilot.ui.theme.pocketPilot

/** StreamingText — read-only Text with an inlineContent cursor while streaming. */
@Composable
fun StreamingText(
    text: String,
    isStreaming: Boolean,
    modifier: Modifier = Modifier,
    textColor: Color = MaterialTheme.colorScheme.onSurface
) {
    if (!isStreaming) {
        ChatMarkdown(
            text = text,
            modifier = modifier,
            color = textColor
        )
        return
    }

    val cursorStyle = MaterialTheme.pocketPilot.serifItalic.copy(
        color = MaterialTheme.colorScheme.primary,
        fontSize = MaterialTheme.typography.bodyLarge.fontSize
    )

    val annotated = remember(text) {
        buildAnnotatedString {
            append(text.trimStart('\n', '\r'))
            appendInlineContent(CURSOR_ID, "|")
        }
    }

    val transition = rememberInfiniteTransition(label = "streamingCursor")
    val alpha by transition.animateFloat(
        initialValue = 1f,
        targetValue = 0f,
        animationSpec = infiniteRepeatable(
            animation = tween(PocketPilotMotion.CursorBlink, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "cursorAlpha"
    )

    val inline = mapOf(
        CURSOR_ID to InlineTextContent(
            placeholder = Placeholder(
                width = 0.5.em,
                height = 1.em,
                placeholderVerticalAlign = PlaceholderVerticalAlign.TextCenter
            )
        ) {
            Text(
                text = "|",
                style = cursorStyle,
                modifier = Modifier
                    .alpha(alpha)
                    .testTag(CURSOR_TEST_TAG)
            )
        }
    )

    Text(
        text = annotated,
        modifier = modifier,
        style = MaterialTheme.typography.bodyLarge,
        color = textColor,
        inlineContent = inline
    )
}

private const val CURSOR_ID = "cursor"
const val CURSOR_TEST_TAG = "qa-streaming-cursor"
