package id.steveimm.pocketpilot.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@Immutable
data class PocketPilotTokens(
    val mutedText: Color,
    val monoBody: TextStyle,
    val monoSmall: TextStyle,
    val spacing: PocketPilotSpacing,
)

@Immutable
data class PocketPilotSpacing(
    val xs: Dp = 4.dp,
    val sm: Dp = 8.dp,
    val md: Dp = 16.dp,
    val lg: Dp = 24.dp,
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
    mutedText = TextMutedLight,
    monoBody = MonoBodyStyle,
    monoSmall = MonoSmallStyle,
    spacing = PocketPilotSpacing(),
)

internal fun darkPocketPilotTokens() = PocketPilotTokens(
    mutedText = TextMutedDark,
    monoBody = MonoBodyStyle,
    monoSmall = MonoSmallStyle,
    spacing = PocketPilotSpacing(),
)
