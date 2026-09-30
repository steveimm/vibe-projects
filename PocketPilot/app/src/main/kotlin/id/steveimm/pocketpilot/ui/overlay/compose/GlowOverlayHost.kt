package id.steveimm.pocketpilot.ui.overlay.compose

import android.accessibilityservice.AccessibilityService
import android.content.ComponentCallbacks
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Paint
import android.view.WindowManager
import id.steveimm.pocketpilot.model.Bounds
import id.steveimm.pocketpilot.ui.overlay.model.GlowState

class GlowOverlayHost(private val service: AccessibilityService) {
    private val manager = service.getSystemService(WindowManager::class.java)
    private val windows = listOf("top", "bottom", "left", "right").map { EffectWindow(service, "PocketPilot border $it") }
    private val paint = Paint().apply { color = Color.rgb(224, 66, 78) }
    private var visible = false
    private val configuration = object : ComponentCallbacks {
        override fun onConfigurationChanged(newConfig: Configuration) { if (visible) place() }
        override fun onLowMemory() = Unit
    }

    init {
        windows.forEach { window -> window.draw = { canvas -> canvas.drawRect(0f, 0f, canvas.width.toFloat(), canvas.height.toFloat(), paint) } }
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
        val line = (2 * service.resources.displayMetrics.density).toInt().coerceAtLeast(2)
        val edges = listOf(Bounds(0, 0, width, line), Bounds(0, height - line, width, height),
            Bounds(0, line, line, height - line), Bounds(width - line, line, width, height - line))
        return windows.zip(edges).all { (window, area) -> window.show(area) }
    }

    fun updateState(state: GlowState) {
        paint.color = when (state) {
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
