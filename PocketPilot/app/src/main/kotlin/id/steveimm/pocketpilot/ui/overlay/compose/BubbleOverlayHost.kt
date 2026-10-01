package id.steveimm.pocketpilot.ui.overlay.compose

import android.accessibilityservice.AccessibilityService
import android.animation.ValueAnimator
import android.view.animation.DecelerateInterpolator
import id.steveimm.pocketpilot.ui.theme.PocketPilotMotion
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
import id.steveimm.pocketpilot.platform.GestureCoordinates
import id.steveimm.pocketpilot.ui.overlay.CapsuleStateHolder
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlin.math.abs
import kotlin.math.roundToInt

class BubbleOverlayHost(
    private val service: AccessibilityService,
    lifecycleOwner: LifecycleOwner,
    savedStateRegistryOwner: SavedStateRegistryOwner,
    private val onToggleCapsule: () -> Unit,
    private val onDismiss: () -> Unit,
    private val onDragStarted: () -> Unit,
    private val onDragFinished: (completed: Boolean) -> Unit,
) {
    private val windowManager = service.getSystemService(WindowManager::class.java)
    private val composeHost = OverlayComposeHost(service, lifecycleOwner, savedStateRegistryOwner, windowManager, "BubbleOverlayHost")
    private val dismissTarget = DismissTargetOverlay(service, lifecycleOwner, savedStateRegistryOwner)
    private val overDismissTarget = MutableStateFlow(false)
    private var gestureActive = false
    private val preferences = service.getSharedPreferences("overlay_bubble", Context.MODE_PRIVATE)
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
    private var dockAnimation: ValueAnimator? = null
    private val injectedGestures = mutableListOf<GestureCoordinates>()
    private val configurationCallback = object : ComponentCallbacks {
        override fun onConfigurationChanged(newConfig: Configuration) { cancelDrag(); placeAtEdge() }
        override fun onLowMemory() = Unit
    }

    fun startObserving(holder: CapsuleStateHolder) { stateHolder = holder }
    fun isShowing(): Boolean = composeHost.isShowing()
    fun isDragging(): Boolean = dragging
    fun suppressForScreenshot(): AutoCloseable {
        val bubble = composeHost.suppressForScreenshot()
        val target = dismissTarget.suppressForScreenshot()
        return AutoCloseable { target.close(); bubble.close() }
    }

    fun isUserTouchActive(): Boolean = gestureActive
    fun isGesturePathClear(): Boolean = !isShowing() || isClearOfGestures(x, y)

    fun beginGesturePassThrough(gesture: GestureCoordinates): AutoCloseable {
        injectedGestures.add(gesture)
        dockAnimation?.cancel()
        if (isShowing() && !gestureActive) moveClearOfGestures()
        var closed = false
        return AutoCloseable {
            if (!closed) {
                closed = true
                injectedGestures.remove(gesture)
                if (isShowing() && !gestureActive) placeAtEdge(animate = injectedGestures.isEmpty())
            }
        }
    }

    fun show() {
        if (isShowing()) return
        val holder = stateHolder ?: return
        placeAtEdge()
        composeHost.show(createLayoutParams()) {
            val mode by holder.mode.collectAsState()
            val captured by overDismissTarget.collectAsState()
            OverlayBubbleCompose(
                capturedForDismissal = captured,
                onDismiss = onDismiss,
                status = when (mode) {
                    is CapsuleMode.Done -> if ((mode as CapsuleMode.Done).stopped) "Stopped" else "Task finished"
                    is CapsuleMode.Error -> "Error"
                    is CapsuleMode.Hidden -> "Ready"
                    is CapsuleMode.Running -> "Working"
                    else -> "Waiting for you"
                },
                onToggle = onToggleCapsule,
                onTouch = ::onTouch,
            )
        }
        if (isShowing()) service.registerComponentCallbacks(configurationCallback)
    }

    fun hide() {
        cancelDrag()
        if (!isShowing()) return
        dockAnimation?.cancel()
        service.unregisterComponentCallbacks(configurationCallback)
        composeHost.hide()
    }

    fun dispose() { hide() }

    private fun onTouch(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                dockAnimation?.cancel()
                downX = event.rawX; downY = event.rawY
                startX = x; startY = y
                dragging = false
                gestureActive = true
            }
            MotionEvent.ACTION_MOVE -> {
                if (!gestureActive) return true
                val dx = event.rawX - downX
                val dy = event.rawY - downY
                val slop = ViewConfiguration.get(service).scaledTouchSlop
                if (!dragging && (abs(dx) > slop || abs(dy) > slop)) {
                    dragging = true
                    onDragStarted()
                    dismissTarget.show()
                }
                if (dragging) {
                    val nextX = startX + dx; val nextY = startY + dy
                    val captured = dismissTarget.contains(nextX + dp(30), nextY + dp(30))
                    if (captured && !overDismissTarget.value) composeHost.hapticFeedback()
                    overDismissTarget.value = captured
                    dismissTarget.highlight(captured)
                    if (captured) moveTo(dismissTarget.center.x - dp(30), dismissTarget.center.y - dp(30))
                    else moveTo(nextX, nextY)
                }
            }
            MotionEvent.ACTION_UP -> {
                if (!gestureActive) return true
                gestureActive = false
                if (dragging) {
                    val dismiss = overDismissTarget.value
                    dragging = false
                    dismissTarget.hide()
                    overDismissTarget.value = false
                    if (dismiss) { onDragFinished(false); onDismiss(); return true }
                    val bounds = movementBounds()
                    rightEdge = x >= (bounds.left + bounds.right) / 2f
                    heightFraction = ((y - bounds.top) / bounds.height().coerceAtLeast(1)).coerceIn(0f, 1f)
                    preferences.edit().putBoolean("right_edge", rightEdge).putFloat("height_fraction", heightFraction).apply()
                    placeAtEdge(animate = true)
                    onDragFinished(true)
                } else {
                    placeAtEdge(animate = injectedGestures.isEmpty())
                    onToggleCapsule()
                }
            }
            MotionEvent.ACTION_CANCEL, MotionEvent.ACTION_POINTER_DOWN -> { cancelDrag(); placeAtEdge() }
        }
        return true
    }

    private fun cancelDrag() {
        val wasDragging = dragging
        gestureActive = false
        dragging = false
        overDismissTarget.value = false
        dismissTarget.hide()
        if (wasDragging) onDragFinished(false)
    }

    private fun movementBounds(): Rect {
        val metrics = windowManager.currentWindowMetrics
        val insets = metrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
        val margin = dp(8)
        val left = insets.left + margin
        val top = insets.top + margin
        val bottom = metrics.bounds.height() - insets.bottom - margin - dp(60)
        return Rect(left, top, (metrics.bounds.width() - insets.right - margin - dp(60)).coerceAtLeast(left), bottom.coerceAtLeast(top))
    }

    private fun placeAtEdge(animate: Boolean = false) {
        if (gestureActive) return
        dockAnimation?.cancel()
        val bounds = movementBounds()
        val targetX = if (rightEdge) bounds.right.toFloat() else bounds.left.toFloat()
        val targetY = (bounds.top + bounds.height() * heightFraction).coerceAtMost(bounds.bottom.toFloat())
        if (injectedGestures.isNotEmpty()) {
            if (isClearOfGestures(targetX, targetY)) moveTo(targetX, targetY)
            else moveClearOfGestures()
            return
        }
        if (!animate || !ValueAnimator.areAnimatorsEnabled()) {
            moveTo(targetX, targetY)
            return
        }
        val originX = x
        val originY = y
        dockAnimation = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = PocketPilotMotion.Standard.toLong()
            interpolator = DecelerateInterpolator()
            addUpdateListener { animator ->
                val fraction = animator.animatedValue as Float
                moveTo(originX + (targetX - originX) * fraction, originY + (targetY - originY) * fraction)
            }
            start()
        }
    }

    private fun moveTo(nextX: Float, nextY: Float) {
        val bounds = movementBounds()
        x = nextX.coerceIn(bounds.left.toFloat(), bounds.right.toFloat())
        y = nextY.coerceIn(bounds.top.toFloat(), bounds.bottom.toFloat())
        composeHost.updateLayoutParams { it.x = x.roundToInt(); it.y = y.roundToInt() }
    }

    private fun isClearOfGestures(left: Float, top: Float): Boolean {
        val margin = dp(2)
        return injectedGestures.none { it.intersects(left - margin, top - margin, left + dp(60) + margin, top + dp(60) + margin) }
    }

    private fun moveClearOfGestures() {
        if (gestureActive || isClearOfGestures(x, y)) return
        val bounds = movementBounds()
        val candidates = buildList {
            for (edge in listOf(bounds.left.toFloat(), bounds.right.toFloat())) {
                add(edge to y)
                add(edge to bounds.top.toFloat())
                add(edge to bounds.bottom.toFloat())
                for (gesture in injectedGestures) {
                    val above = minOf(gesture.startY, gesture.endY) - dp(60) - dp(4)
                    val below = maxOf(gesture.startY, gesture.endY) + dp(4)
                    add(edge to above.coerceIn(bounds.top.toFloat(), bounds.bottom.toFloat()))
                    add(edge to below.coerceIn(bounds.top.toFloat(), bounds.bottom.toFloat()))
                }
            }
        }
        val position = candidates.filter { (left, top) -> isClearOfGestures(left, top) }
            .minByOrNull { (left, top) -> (left - x) * (left - x) + (top - y) * (top - y) } ?: return
        moveTo(position.first, position.second)
    }

    @SuppressLint("RtlHardcoded")
    private fun createLayoutParams() = WindowManager.LayoutParams(
        dp(60), dp(60), WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
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
