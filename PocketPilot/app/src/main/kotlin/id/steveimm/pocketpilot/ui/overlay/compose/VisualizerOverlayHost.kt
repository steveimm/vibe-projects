package id.steveimm.pocketpilot.ui.overlay.compose

import android.accessibilityservice.AccessibilityService
import android.animation.ValueAnimator
import android.content.ComponentCallbacks
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.WindowManager
import android.view.animation.LinearInterpolator
import kotlin.math.roundToInt

class VisualizerOverlayHost(private val service: AccessibilityService) {
    private val manager = service.getSystemService(WindowManager::class.java)
    private val window = EffectWindow(service, "PocketPilot gesture")
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(224, 66, 78) }
    private var animator: ValueAnimator? = null
    private var observing = false
    private var disposed = false
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private var pendingHide: Runnable? = null
    private val configuration = object : ComponentCallbacks {
        override fun onConfigurationChanged(newConfig: Configuration) { hide() }
        override fun onLowMemory() = Unit
    }

    fun showClick(x: Float, y: Float, longPress: Boolean, durationMs: Long = if (longPress) 1000 else 100) {
        animate(x, y, x, y, durationMs, longPress)
    }
    fun showSwipe(startX: Float, startY: Float, endX: Float, endY: Float, durationMs: Long) {
        animate(startX, startY, endX, endY, durationMs, false)
    }

    private fun animate(startX: Float, startY: Float, endX: Float, endY: Float, durationMs: Long, hold: Boolean) {
        if (disposed) return
        hide()
        observing = true
        service.registerComponentCallbacks(configuration)
        val density = service.resources.displayMetrics.density
        val screen = manager.maximumWindowMetrics.bounds
        if (screen.isEmpty) { hide(); return }
        val duration = durationMs.coerceAtLeast(1)
        val total = duration + 250
        val size = (64 * density).roundToInt()
        fun frame(elapsed: Float) {
            val progress = (elapsed / duration).coerceIn(0f, 1f)
            val x = startX + (endX - startX) * progress
            val y = startY + (endY - startY) * progress
            val bounds = markerBounds(x, y, size, screen.width(), screen.height())
            val fade = if (elapsed <= duration) 1f else (1f - (elapsed - duration) / 250).coerceIn(0f, 1f)
            window.draw = { canvas ->
                val cx = x - bounds.left; val cy = y - bounds.top
                val radius = (if (hold) 22f else 10f + 12f * progress) * density
                paint.style = Paint.Style.FILL; paint.alpha = (45 * fade).toInt()
                canvas.drawCircle(cx, cy, radius, paint)
                paint.style = Paint.Style.STROKE; paint.strokeWidth = 2 * density; paint.alpha = (230 * fade).toInt()
                if (hold) canvas.drawArc(RectF(cx-radius, cy-radius, cx+radius, cy+radius), -90f, 360 * progress, false, paint)
                else canvas.drawCircle(cx, cy, radius, paint)
                paint.style = Paint.Style.FILL
                canvas.drawCircle(cx, cy, 3 * density, paint)
            }
            window.show(bounds)
        }
        if (!ValueAnimator.areAnimatorsEnabled()) {
            frame(duration.toFloat())
            pendingHide = Runnable { hide() }.also { handler.postDelayed(it, total) }
            return
        }
        animator = ValueAnimator.ofFloat(0f, total.toFloat()).apply {
            this.duration = total
            interpolator = LinearInterpolator()
            addUpdateListener { frame(it.animatedValue as Float) }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) { if (animator === animation) hide() }
            })
            start()
        }
    }

    fun suppressForScreenshot(): AutoCloseable = window.suppressForScreenshot()
    fun hide() {
        pendingHide?.let(handler::removeCallbacks)
        pendingHide = null
        val previous = animator
        animator = null
        previous?.cancel()
        window.hide()
        if (observing) service.unregisterComponentCallbacks(configuration)
        observing = false
    }
    fun dispose() { disposed = true; hide() }
}
