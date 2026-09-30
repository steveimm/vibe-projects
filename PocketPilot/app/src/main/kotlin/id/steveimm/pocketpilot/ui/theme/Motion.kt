package id.steveimm.pocketpilot.ui.theme

import android.provider.Settings
import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext

internal val LocalReducedMotion = staticCompositionLocalOf { false }

@Composable
internal fun observeReducedMotion(): Boolean {
    val resolver = LocalContext.current.contentResolver
    fun read(): Boolean = Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    var reduced by remember(resolver) { mutableStateOf(read()) }
    DisposableEffect(resolver) {
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) { reduced = read() }
        }
        resolver.registerContentObserver(Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE), false, observer)
        reduced = read()
        onDispose { resolver.unregisterContentObserver(observer) }
    }
    return reduced
}

object PocketPilotMotion {

    // Durations (ms)
    const val Quick: Int = 120
    const val Standard: Int = 240
    const val Pulse: Int = 480
    const val Breath: Int = 900

    // Easings
    val EaseInOutSine: Easing = CubicBezierEasing(0.37f, 0f, 0.63f, 1f)
    val EaseOutCubic: Easing = CubicBezierEasing(0.33f, 1f, 0.68f, 1f)

    // Shared durations keep related transitions consistent.
    const val StatusFlip: Int = Quick           // 120ms status/glyph flip
    const val TraceEnter: Int = Standard        // 240ms trace-item enter
    const val RowExpand: Int = Standard         // 240ms row expand/collapse
    const val PageSlide: Int = Standard         // 240ms settings page slide
    const val SurfaceSwap: Int = Standard       // 240ms surface/content/color transition
    const val CursorBlink: Int = Pulse          // 480ms cursor blink
    const val ThinkingPulse: Int = Pulse        // 480ms thinking pulse
    const val OverlayFadeOut: Int = Pulse       // 480ms overlay fade-out
    const val CapsuleBreath: Int = Breath       // 900ms capsule breath in running mode
    const val GlowPulse: Int = Breath           // 900ms glow pulse

    @Composable
    fun reducedMotion(): Boolean = LocalReducedMotion.current
}
