package id.steveimm.pocketpilot.ui.overlay.compose

import android.accessibilityservice.AccessibilityService
import android.annotation.SuppressLint
import android.graphics.Canvas
import android.graphics.PixelFormat
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import id.steveimm.pocketpilot.model.Bounds

/** A non-interactive window whose bounds contain only the visual effect. */
internal class EffectWindow(private val service: AccessibilityService, private val name: String) {
    private val manager = service.getSystemService(WindowManager::class.java)
    private var view: View? = null
    private var params: WindowManager.LayoutParams? = null
    private var hiddenForCapture = 0
    var draw: (Canvas) -> Unit = {}

    @SuppressLint("RtlHardcoded")
    fun show(bounds: Bounds): Boolean {
        val current = view
        if (current != null) {
            val layout = params ?: return false
            if (layout.x != bounds.left || layout.y != bounds.top || layout.width != bounds.width || layout.height != bounds.height) {
                layout.x = bounds.left; layout.y = bounds.top; layout.width = bounds.width; layout.height = bounds.height
                try { manager.updateViewLayout(current, layout) } catch (e: Exception) { Log.w(name, "Could not move effect", e) }
            }
            current.invalidate()
            return true
        }
        val effect = object : View(service) {
            override fun onDraw(canvas: Canvas) { this@EffectWindow.draw(canvas) }
        }.apply {
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            alpha = if (hiddenForCapture > 0) 0f else 1f
        }
        val layout = WindowManager.LayoutParams(bounds.width, bounds.height, WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN, PixelFormat.TRANSLUCENT).apply {
            title = name
            gravity = Gravity.TOP or Gravity.LEFT
            x = bounds.left; y = bounds.top
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            setFitInsetsTypes(0)
        }
        return try {
            manager.addView(effect, layout)
            view = effect; params = layout
            true
        } catch (e: Exception) { Log.w(name, "Could not show effect", e); false }
    }

    fun invalidate() { view?.invalidate() }
    fun hide() {
        view?.let { try { manager.removeViewImmediate(it) } catch (e: Exception) { Log.w(name, "Could not remove effect", e) } }
        view = null; params = null
    }

    fun suppressForScreenshot(): AutoCloseable {
        hiddenForCapture++
        view?.alpha = 0f
        var closed = false
        return AutoCloseable {
            if (!closed) {
                closed = true
                hiddenForCapture--
                view?.alpha = if (hiddenForCapture > 0) 0f else 1f
            }
        }
    }
}

internal fun markerBounds(x: Float, y: Float, size: Int, width: Int, height: Int): Bounds {
    val w = size.coerceIn(1, width)
    val h = size.coerceIn(1, height)
    val left = (x - w / 2).toInt().coerceIn(0, width - w)
    val top = (y - h / 2).toInt().coerceIn(0, height - h)
    return Bounds(left, top, left + w, top + h)
}
