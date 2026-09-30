package id.steveimm.pocketpilot.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val PocketPilotLightColorScheme = lightColorScheme(
    primary = BlueLight, onPrimary = SurfaceLight,
    primaryContainer = BlueContainerLight, onPrimaryContainer = Color(0xFF123C8F),
    secondary = SuccessLight, onSecondary = SurfaceLight,
    secondaryContainer = SuccessContainerLight, onSecondaryContainer = Color(0xFF105B3F),
    tertiary = WarningLight, onTertiary = SurfaceLight,
    tertiaryContainer = WarningContainerLight, onTertiaryContainer = Color(0xFF674008),
    error = ErrorLight, onError = SurfaceLight,
    errorContainer = ErrorContainerLight, onErrorContainer = Color(0xFF842035),
    background = BackgroundLight, onBackground = TextLight,
    surface = SurfaceLight, onSurface = TextLight,
    surfaceVariant = SurfaceLowLight, onSurfaceVariant = TextMutedLight,
    surfaceContainerLowest = SurfaceLight, surfaceContainerLow = SurfaceLowLight,
    surfaceContainer = Color(0xFFEAF0F9), surfaceContainerHigh = SurfaceHighLight,
    surfaceContainerHighest = Color(0xFFDAE4F4),
    outline = OutlineLight, outlineVariant = DividerLight,
    inverseSurface = SurfaceDark, inverseOnSurface = TextDark, inversePrimary = BlueDark,
    surfaceTint = BlueLight,
)

private val PocketPilotDarkColorScheme = darkColorScheme(
    primary = BlueDark, onPrimary = Color(0xFF10254B),
    primaryContainer = BlueContainerDark, onPrimaryContainer = Color(0xFFDCE8FF),
    secondary = SuccessDark, onSecondary = Color(0xFF073D28),
    secondaryContainer = SuccessContainerDark, onSecondaryContainer = Color(0xFFB9F3D8),
    tertiary = WarningDark, onTertiary = Color(0xFF432D08),
    tertiaryContainer = WarningContainerDark, onTertiaryContainer = Color(0xFFFFDCA5),
    error = ErrorDark, onError = Color(0xFF5F1225),
    errorContainer = ErrorContainerDark, onErrorContainer = Color(0xFFFFD9E0),
    background = BackgroundDark, onBackground = TextDark,
    surface = SurfaceDark, onSurface = TextDark,
    surfaceVariant = SurfaceHighDark, onSurfaceVariant = TextMutedDark,
    surfaceContainerLowest = BackgroundDark, surfaceContainerLow = SurfaceLowDark,
    surfaceContainer = SurfaceDark, surfaceContainerHigh = SurfaceHighDark,
    surfaceContainerHighest = Color(0xFF29384E),
    outline = OutlineDark, outlineVariant = DividerDark,
    inverseSurface = SurfaceLight, inverseOnSurface = TextLight, inversePrimary = BlueLight,
    surfaceTint = BlueDark,
)

@Composable
fun PocketPilotTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colorScheme = if (darkTheme) PocketPilotDarkColorScheme else PocketPilotLightColorScheme
    val tokens = if (darkTheme) darkPocketPilotTokens() else lightPocketPilotTokens()

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val activity = view.context as? Activity
            if (activity != null) {
                val window = activity.window
                WindowCompat.getInsetsController(window, view).apply {
                    isAppearanceLightStatusBars = !darkTheme
                    isAppearanceLightNavigationBars = !darkTheme
                }
                if (Build.VERSION.SDK_INT < 35) {
                    @Suppress("DEPRECATION")
                    window.statusBarColor = colorScheme.background.toArgb()
                    @Suppress("DEPRECATION")
                    window.navigationBarColor = colorScheme.background.toArgb()
                }
            }
        }
    }

    CompositionLocalProvider(
        LocalPocketPilotTokens provides tokens,
        LocalContentColor provides colorScheme.onBackground,
        LocalReducedMotion provides observeReducedMotion(),
    ) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = PocketPilotTypography,
            shapes = PocketPilotShapes,
            content = content,
        )
    }
}
