package id.steveimm.pocketpilot.ui.overlay.compose

import android.accessibilityservice.AccessibilityService
import android.content.ComponentCallbacks
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.view.WindowManager
import id.steveimm.pocketpilot.model.Bounds
import id.steveimm.pocketpilot.ui.overlay.model.GlowState

class GlowOverlayHost(private val service: AccessibilityService) {
    private val manager = service.getSystemService(WindowManager::class.java)
    private val windows = listOf("top", "bottom", "left", "right").map { EffectWindow(service, "PocketPilot border $it") }
    private val paint = Paint()
    private var color = Color.rgb(224, 66, 78)
    private var visible = false
    private val configuration = object : ComponentCallbacks {
        override fun onConfigurationChanged(newConfig: Configuration) { if (visible) place() }
        override fun onLowMemory() = Unit
    }

    init {
        windows.forEachIndexed { index, window ->
            window.draw = { canvas ->
                val width = canvas.width.toFloat()
                val height = canvas.height.toFloat()
                val startX = if (index == 3) width else 0f
                val startY = if (index == 1) height else 0f
                val endX = if (index == 2) width else 0f
                val endY = if (index == 0) height else 0f
                val edgeColor = Color.argb(179, Color.red(color), Color.green(color), Color.blue(color))
                val innerColor = Color.argb(0, Color.red(color), Color.green(color), Color.blue(color))
                paint.shader = LinearGradient(startX, startY, endX, endY, edgeColor, innerColor, Shader.TileMode.CLAMP)
                canvas.drawRect(0f, 0f, width, height, paint)
            }
        }
    }

    fun isShowing(): Boolean = visible
    fun show(state: GlowState = GlowState.Active) {
        updateState(state)
        if (!visible) { visible = true; service.registerComponentCallbacks(configuration) }
        if (!place()) hideImmediately()
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
        color = when (state) {
            GlowState.Paused -> Color.rgb(176, 127, 40)
            GlowState.Success -> Color.rgb(27, 134, 91)
            else -> Color.rgb(224, 66, 78)
        }
        windows.forEach { it.invalidate() }
    }

    fun hideImmediately() {
        if (visible) service.unregisterComponentCallbacks(configuration)
        visible = false
        windows.forEach { it.hide() }
    }
    fun dispose() { hideImmediately() }
    fun suppressForScreenshot(): AutoCloseable {
        val leases = windows.map { it.suppressForScreenshot() }
        return AutoCloseable { leases.forEach { it.close() } }
    }
}
