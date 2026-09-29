package id.steveimm.pocketpilot.ui.overlay.compose

import android.accessibilityservice.AccessibilityService
import android.annotation.SuppressLint
import android.content.ComponentCallbacks
import android.content.Context
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.graphics.Rect
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.view.WindowInsets
import android.view.WindowManager
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.LifecycleOwner
import androidx.savedstate.SavedStateRegistryOwner
import id.steveimm.pocketpilot.ui.capsule.surface.toStatusColor
import id.steveimm.pocketpilot.ui.overlay.CapsuleStateHolder
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import id.steveimm.pocketpilot.ui.overlay.model.deriveGlowState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlin.math.abs
import kotlin.math.roundToInt

class BubbleOverlayHost(
    private val service: AccessibilityService,
    lifecycleOwner: LifecycleOwner,
    savedStateRegistryOwner: SavedStateRegistryOwner,
    private val onToggleCapsule: () -> Unit,
) {
    private val windowManager = service.getSystemService(WindowManager::class.java)
    private val composeHost = OverlayComposeHost(service, lifecycleOwner, savedStateRegistryOwner, windowManager, "BubbleOverlayHost")
    private val preferences = service.getSharedPreferences("overlay_bubble", Context.MODE_PRIVATE)
    private val expanded = MutableStateFlow(false)
    private var stateHolder: CapsuleStateHolder? = null
    private var rightEdge = preferences.getBoolean("right_edge", true)
    private var heightFraction = preferences.getFloat("height_fraction", 0.3f)
    private var x = 0f
    private var y = 0f
    private var downX = 0f
    private var downY = 0f
    private var startX = 0f
    private var startY = 0f
    private var dragging = false
    private var passThroughDepth = 0
    private val configurationCallback = object : ComponentCallbacks {
        override fun onConfigurationChanged(newConfig: Configuration) { placeAtEdge() }
        override fun onLowMemory() = Unit
    }

    fun startObserving(holder: CapsuleStateHolder) { stateHolder = holder }
    fun setExpanded(value: Boolean) { expanded.value = value }
    fun isShowing(): Boolean = composeHost.isShowing()
    fun suppressForScreenshot(): AutoCloseable = composeHost.suppressForScreenshot()

    fun beginGesturePassThrough(): AutoCloseable {
        passThroughDepth++
        updateTouchability()
        var closed = false
        return AutoCloseable {
            if (!closed) {
                closed = true
                passThroughDepth--
                updateTouchability()
            }
        }
    }

    fun show() {
        if (isShowing()) return
        val holder = stateHolder ?: return
        placeAtEdge()
        composeHost.show(createLayoutParams()) {
            val mode by holder.mode.collectAsState()
            val phase by holder.turnPhase.collectAsState()
            val isExpanded by expanded.collectAsState()
            OverlayBubbleCompose(
                expanded = isExpanded,
                status = when (mode) {
                    is CapsuleMode.Done -> "Task finished"
                    is CapsuleMode.Error -> "Error"
                    is CapsuleMode.Hidden -> "Ready"
                    is CapsuleMode.Running -> "Working"
                    else -> "Waiting for you"
                },
                statusColor = deriveGlowState(mode, phase).toStatusColor(),
                onToggle = onToggleCapsule,
                onTouch = ::onTouch,
            )
        }
        if (isShowing()) service.registerComponentCallbacks(configurationCallback)
    }

    fun hide() {
        if (!isShowing()) return
        service.unregisterComponentCallbacks(configurationCallback)
        composeHost.hide()
    }

    fun dispose() { hide() }

    private fun onTouch(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = event.rawX
                downY = event.rawY
                startX = x
                startY = y
                dragging = false
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - downX
                val dy = event.rawY - downY
                val slop = ViewConfiguration.get(service).scaledTouchSlop
                if (abs(dx) > slop || abs(dy) > slop) dragging = true
                if (dragging) moveTo(startX + dx, startY + dy)
            }
            MotionEvent.ACTION_UP -> {
                if (dragging) {
                    val bounds = movementBounds()
                    rightEdge = x >= (bounds.left + bounds.right) / 2f
                    heightFraction = if (bounds.height() == 0) 0f else (y - bounds.top) / bounds.height()
                    preferences.edit().putBoolean("right_edge", rightEdge).putFloat("height_fraction", heightFraction).apply()
                    placeAtEdge()
                } else onToggleCapsule()
            }
            MotionEvent.ACTION_CANCEL -> placeAtEdge()
        }
        return true
    }

    private fun movementBounds(): Rect {
        val metrics = windowManager.currentWindowMetrics
        val insets = metrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
        val margin = dp(8)
        val left = insets.left + margin
        val top = insets.top + margin
        return Rect(left, top, (metrics.bounds.width() - insets.right - margin - dp(60)).coerceAtLeast(left),
            (metrics.bounds.height() - insets.bottom - margin - dp(60)).coerceAtLeast(top))
    }

    private fun placeAtEdge() {
        val bounds = movementBounds()
        moveTo(if (rightEdge) bounds.right.toFloat() else bounds.left.toFloat(), bounds.top + bounds.height() * heightFraction)
    }

    private fun moveTo(nextX: Float, nextY: Float) {
        val bounds = movementBounds()
        x = nextX.coerceIn(bounds.left.toFloat(), bounds.right.toFloat())
        y = nextY.coerceIn(bounds.top.toFloat(), bounds.bottom.toFloat())
        composeHost.updateLayoutParams { it.x = x.roundToInt(); it.y = y.roundToInt() }
    }

    private fun updateTouchability() {
        composeHost.updateLayoutParams {
            it.flags = if (passThroughDepth > 0) it.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
            else it.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        }
    }

    @SuppressLint("RtlHardcoded")
    private fun createLayoutParams() = WindowManager.LayoutParams(
        dp(60), dp(60), WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            (if (passThroughDepth > 0) WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE else 0),
        PixelFormat.TRANSLUCENT,
    ).apply {
        title = "PocketPilot bubble"
        gravity = Gravity.TOP or Gravity.LEFT
        layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        setFitInsetsTypes(0)
        softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
        x = this@BubbleOverlayHost.x.roundToInt()
        y = this@BubbleOverlayHost.y.roundToInt()
    }

    private fun dp(value: Int): Int = (value * service.resources.displayMetrics.density).roundToInt()
}
