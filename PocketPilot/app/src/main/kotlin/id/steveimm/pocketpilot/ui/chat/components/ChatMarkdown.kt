package id.steveimm.pocketpilot.ui.chat.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import com.mikepenz.markdown.m3.Markdown
import com.mikepenz.markdown.m3.markdownColor
import com.mikepenz.markdown.m3.markdownTypography
import com.mikepenz.markdown.model.NoOpImageTransformerImpl
import com.mikepenz.markdown.model.ReferenceLinkHandlerImpl
import com.mikepenz.markdown.model.markdownAnimations
import com.mikepenz.markdown.model.rememberMarkdownState
import org.intellij.markdown.flavours.gfm.GFMFlavourDescriptor
import org.intellij.markdown.parser.MarkdownParser

@Composable
internal fun ChatMarkdown(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.onSurface,
    style: TextStyle = MaterialTheme.typography.bodyLarge,
) {
    val content = text.trim('\n', '\r')
    val flavour = remember { GFMFlavourDescriptor() }
    val parser = remember(content) { MarkdownParser(flavour) }
    val links = remember(content) { ReferenceLinkHandlerImpl() }
    val state = rememberMarkdownState(content, flavour = flavour, parser = parser, referenceLinkHandler = links)
    Markdown(
        markdownState = state,
        modifier = modifier.fillMaxWidth(),
        colors = markdownColor(),
        typography = markdownTypography(
            h1 = MaterialTheme.typography.headlineSmall,
            h2 = MaterialTheme.typography.titleLarge,
            h3 = MaterialTheme.typography.titleMedium,
            h4 = MaterialTheme.typography.titleMedium,
            h5 = MaterialTheme.typography.titleSmall,
            h6 = MaterialTheme.typography.titleSmall,
            text = style.copy(color = color), paragraph = style.copy(color = color),
            ordered = style.copy(color = color), bullet = style.copy(color = color), list = style.copy(color = color),
            link = style.copy(color = MaterialTheme.colorScheme.primary),
        ),
        imageTransformer = remember { NoOpImageTransformerImpl() },
        animations = markdownAnimations(animateTextSize = { this }),
        loading = { Text(content, style = style, color = color) },
        error = { Text(content, style = style, color = color) },
    )
}
