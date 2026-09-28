package id.steveimm.pocketpilot.ui.theme

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.runtime.Composable

/** App-wide window insets configuration. */
object AppWindowInsets {
    /** Full system bars (status bar + navigation bar). Use for main screen content. */
    val systemBars: WindowInsets
        @Composable get() = WindowInsets.systemBars

    /** Status bar only. Use for top-aligned content like headers, drawers, top sheets. */
    val statusBars: WindowInsets
        @Composable get() = WindowInsets.statusBars

    /** Navigation bar only. Use for bottom-aligned content like input docks, bottom sheets. */
    val navigationBars: WindowInsets
        @Composable get() = WindowInsets.navigationBars

    /** No insets - content goes edge-to-edge. Use when parent already handles insets. */
    val none: WindowInsets
        @Composable get() = WindowInsets(0, 0, 0, 0)
}
