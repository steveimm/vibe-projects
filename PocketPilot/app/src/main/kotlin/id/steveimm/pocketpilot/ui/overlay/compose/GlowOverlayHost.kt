package id.steveimm.pocketpilot.ui.overlay.compose

import android.accessibilityservice.AccessibilityService
import android.animation.ValueAnimator
import android.content.ComponentCallbacks
import android.content.res.Configuration
import android.database.ContentObserver
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Shader
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import id.steveimm.pocketpilot.model.Bounds
import id.steveimm.pocketpilot.ui.overlay.model.GlowState
import id.steveimm.pocketpilot.ui.theme.PocketPilotMotion
import kotlin.math.roundToInt

class GlowOverlayHost(private val service: AccessibilityService) {
    private val manager = service.getSystemService(WindowManager::class.java)
    private val windows = listOf("top", "bottom", "left", "right").map { EffectWindow(service, "PocketPilot border $it") }
    private val paints = windows.map { Paint() }
    private var color = Color.rgb(224, 66, 78)
    private var visible = false
    private var state = GlowState.Active
    private var pulseFraction = 1f
    private var pulseAnimator: ValueAnimator? = null
    private val motionObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
        override fun onChange(selfChange: Boolean) { updatePulse() }
    }
    private val configuration = object : ComponentCallbacks {
        override fun onConfigurationChanged(newConfig: Configuration) { if (visible) place() }
        override fun onLowMemory() = Unit
    }

    init {
        updateShaders()
        windows.forEachIndexed { index, window ->
            val paint = paints[index]
            val matrix = Matrix()
            window.draw = { canvas ->
                val width = canvas.width.toFloat()
                val height = canvas.height.toFloat()
                val depth = (if (index < 2) height else width) * (0.65f + 0.35f * pulseFraction)
                matrix.setScale(depth, depth)
                matrix.postTranslate(if (index == 3) width else 0f, if (index == 1) height else 0f)
                paint.shader?.setLocalMatrix(matrix)
                paint.alpha = (128 + 51 * pulseFraction).roundToInt()
                canvas.drawRect(0f, 0f, width, height, paint)
            }
        }
    }

    fun isShowing(): Boolean = visible
    fun show(state: GlowState = GlowState.Active) {
        updateState(state)
        if (!visible) {
            visible = true
            service.registerComponentCallbacks(configuration)
            service.contentResolver.registerContentObserver(
                Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE), false, motionObserver,
            )
        }
        if (place()) updatePulse() else hideImmediately()
    }

    private fun place(): Boolean {
        val bounds = manager.maximumWindowMetrics.bounds
        val width = bounds.width(); val height = bounds.height()
        val depth = (40 * service.resources.displayMetrics.density).toInt().coerceIn(1, minOf(width, height))
        val edges = listOf(Bounds(0, 0, width, depth), Bounds(0, height - depth, width, height),
            Bounds(0, 0, depth, height), Bounds(width - depth, 0, width, height))
        return windows.zip(edges).all { (window, area) -> window.show(area) }
    }

    fun updateState(state: GlowState) {
        this.state = state
        val nextColor = when (state) {
            GlowState.Paused -> Color.rgb(176, 127, 40)
            GlowState.Success -> Color.rgb(27, 134, 91)
            else -> Color.rgb(224, 66, 78)
        }
        if (color != nextColor) {
            color = nextColor
            updateShaders()
        }
        updatePulse()
        windows.forEach { it.invalidate() }
    }

    private fun updateShaders() {
        val transparent = Color.argb(0, Color.red(color), Color.green(color), Color.blue(color))
        paints.forEachIndexed { index, paint ->
            val endX = when (index) { 2 -> 1f; 3 -> -1f; else -> 0f }
            val endY = when (index) { 0 -> 1f; 1 -> -1f; else -> 0f }
            paint.shader = LinearGradient(0f, 0f, endX, endY, color, transparent, Shader.TileMode.CLAMP)
        }
    }

    private fun updatePulse() {
        val animate = visible && (state == GlowState.Active || state == GlowState.Executing) && ValueAnimator.areAnimatorsEnabled()
        if (!animate) {
            stopPulse()
            windows.forEach { it.invalidate() }
        } else if (pulseAnimator == null) {
            pulseAnimator = ValueAnimator.ofFloat(1f, 0f).apply {
                duration = PocketPilotMotion.GlowPulse.toLong()
                repeatCount = ValueAnimator.INFINITE
                repeatMode = ValueAnimator.REVERSE
                interpolator = AccelerateDecelerateInterpolator()
                addUpdateListener {
                    pulseFraction = it.animatedValue as Float
                    windows.forEach { window -> window.invalidate() }
                }
                start()
            }
        }
    }

    private fun stopPulse() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        pulseFraction = 1f
    }

    fun hideImmediately() {
        if (visible) {
            service.unregisterComponentCallbacks(configuration)
            service.contentResolver.unregisterContentObserver(motionObserver)
        }
        visible = false
        stopPulse()
        windows.forEach { it.hide() }
    }
    fun dispose() { hideImmediately() }
    fun suppressForScreenshot(): AutoCloseable {
        val leases = windows.map { it.suppressForScreenshot() }
        return AutoCloseable { leases.forEach { it.close() } }
    }
}
