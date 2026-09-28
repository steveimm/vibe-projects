package id.steveimm.pocketpilot.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// The single thin extension surface beyond Material. Carries D1 residue that
// Material slots do not model: extra text roles, identity/mono styles, and
// the four spacing tiers Material does not standardize.
@Immutable
data class PocketPilotTokens(
    val inkFaint: Color,
    val bodyItalic: TextStyle,
    val serifItalic: TextStyle,
    val monoBody: TextStyle,
    val monoSmall: TextStyle,
    val spacing: PocketPilotSpacing,
)

@Immutable
data class PocketPilotSpacing(
    val xs: Dp = 4.dp,
    val sm: Dp = 8.dp,
    val md: Dp = 12.dp,
    val lg: Dp = 20.dp,
    val xl: Dp = 32.dp,
    // Intent aliases — same baseline grid, named for the slot they document.
    val cardPadding: Dp = 16.dp,
    val pagePadding: Dp = 20.dp,
)

internal val LocalPocketPilotTokens = compositionLocalOf<PocketPilotTokens> {
    error("PocketPilotTokens not provided. Wrap your content in PocketPilotTheme { ... }.")
}

val MaterialTheme.pocketPilot: PocketPilotTokens
    @Composable
    @ReadOnlyComposable
    get() = LocalPocketPilotTokens.current

internal fun lightPocketPilotTokens() = PocketPilotTokens(
    inkFaint = InkFaint,
    bodyItalic = BodyItalicStyle,
    serifItalic = SerifItalicStyle,
    monoBody = MonoBodyStyle,
    monoSmall = MonoSmallStyle,
    spacing = PocketPilotSpacing(),
)

internal fun darkPocketPilotTokens() = PocketPilotTokens(
    inkFaint = InkFaintDark,
    bodyItalic = BodyItalicStyle,
    serifItalic = SerifItalicStyle,
    monoBody = MonoBodyStyle,
    monoSmall = MonoSmallStyle,
    spacing = PocketPilotSpacing(),
)

// D1 §4.4: subtle warm under-shadow only — the "lift" effect. (The earlier
// top hairline read as a divider on small cards after foldedPaper was
// extended to Settings rows in Phase 3, so it was removed.)
@Composable
fun Modifier.foldedPaper(shape: Shape = MaterialTheme.shapes.large): Modifier {
    val warm = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.22f)
    return this.shadow(elevation = 4.dp, shape = shape, ambientColor = warm, spotColor = warm)
}
