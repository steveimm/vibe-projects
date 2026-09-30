package id.steveimm.pocketpilot.ui.overlay.visualizer

import android.accessibilityservice.AccessibilityService
import id.steveimm.pocketpilot.ui.overlay.compose.VisualizerOverlayHost
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleContext
import kotlinx.coroutines.flow.StateFlow

/** Routes action feedback to its bounded overlay window. */
class ActionVisualizerManager(
    context: AccessibilityService,
    private val renderContext: StateFlow<CapsuleContext>,
    enabled: Boolean,
) {
    private val overlayHost = VisualizerOverlayHost(
        service = context,
    )

    @Volatile
    var enabled: Boolean = enabled
        set(value) {
            field = value
            if (!value) overlayHost.hide()
        }

    var screenAvailable: Boolean = true
        set(value) { field = value; if (!value) overlayHost.hide() }

    fun suppressForScreenshot(): AutoCloseable = overlayHost.suppressForScreenshot()

    fun showClick(x: Float, y: Float, longPress: Boolean = false, durationMs: Long = if (longPress) 1000 else 100) {
        if (!shouldRender()) return
        overlayHost.showClick(x = x, y = y, longPress = longPress, durationMs = durationMs)
    }

    fun showSwipe(
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        durationMs: Long,
    ) {
        if (!shouldRender()) return
        overlayHost.showSwipe(
            startX = startX,
            startY = startY,
            endX = endX,
            endY = endY,
            durationMs = durationMs,
        )
    }

    fun hide() { overlayHost.hide() }

    fun dispose() {
        overlayHost.dispose()
    }

    private fun shouldRender(): Boolean =
        enabled && screenAvailable && renderContext.value == CapsuleContext.SCREEN_VIEWING
}
