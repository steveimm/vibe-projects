package id.steveimm.pocketpilot.platform

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.PathMeasure
import android.os.Build
import android.util.Log
import android.view.Display
import android.view.ViewConfiguration
import id.steveimm.pocketpilot.ui.overlay.visualizer.ActionVisualizerManager
import kotlin.coroutines.resume
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

/** Accessibility gesture/global-action executor. */
class AccessibilityGestureInjector(
        private val service: AccessibilityService,
        private val visualizer: ActionVisualizerManager? = null,
        private val overlayTouchGate: OverlayTouchGate? = null,
) {
    companion object {
        private const val TAG = "AccessibilityGestureInjector"
        private const val GESTURE_TIMEOUT_MS = 5000L
        /** Delay after setting FLAG_NOT_TOUCHABLE to let WindowManagerService process it. */
        private const val FLAG_SETTLE_MS = 50L
    }

    suspend fun injectTap(x: Int, y: Int): ActionResult {
        return withContext(Dispatchers.Main) {
            val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
            val tapDuration = ViewConfiguration.getTapTimeout().toLong()
            val stroke = GestureDescription.StrokeDescription(path, 0, tapDuration)
            val gesture = buildGesture(stroke)

            dispatchGesture(gesture, GestureCoordinates(x.toFloat(), y.toFloat())) {
                visualizer?.showClick(x.toFloat(), y.toFloat(), durationMs = tapDuration)
            }
        }
    }

    suspend fun injectSwipe(
            startX: Float,
            startY: Float,
            endX: Float,
            endY: Float,
            durationMs: Long
    ): ActionResult {
        return withContext(Dispatchers.Main) {
            val path =
                    Path().apply {
                        moveTo(startX, startY)
                        lineTo(endX, endY)
                    }
            val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
            val gesture = buildGesture(stroke)
            dispatchGesture(gesture, GestureCoordinates(startX, startY, endX, endY)) {
                visualizer?.showSwipe(startX, startY, endX, endY, durationMs)
            }
        }
    }

    suspend fun injectLongPress(x: Float, y: Float, durationMs: Long): ActionResult {
        return withContext(Dispatchers.Main) {
            val path = Path().apply { moveTo(x, y) }
            val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
            val gesture = buildGesture(stroke)
            dispatchGesture(gesture, GestureCoordinates(x, y)) {
                visualizer?.showClick(x, y, longPress = true, durationMs = durationMs)
            }
        }
    }

    suspend fun injectSystemButton(button: SystemButtonType): ActionResult {
        return withContext(Dispatchers.Main) {
            val globalAction =
                    when (button) {
                        SystemButtonType.BACK -> AccessibilityService.GLOBAL_ACTION_BACK
                        SystemButtonType.HOME -> AccessibilityService.GLOBAL_ACTION_HOME
                        SystemButtonType.RECENTS -> AccessibilityService.GLOBAL_ACTION_RECENTS
                        SystemButtonType.ENTER ->
                                return@withContext ActionResult.Failure(
                                        "ENTER should be handled by NodeActionPerformer"
                                )
                    }

            val result = service.performGlobalAction(globalAction)
            if (result) {
                ActionResult.Success("System button: $button")
            } else {
                ActionResult.Failure("Failed to perform system action: $button")
            }
        }
    }

    private suspend fun dispatchGesture(
        gesture: GestureDescription,
        coordinates: GestureCoordinates,
        visualize: () -> Unit,
    ): ActionResult {
        val gate = overlayTouchGate
        if (gate?.awaitGestureAccess() == false) return ActionResult.Cancelled("User is interacting with PocketPilot controls")
        var token = gate?.beginGesturePassThrough(coordinates)
        var completed = false
        var interrupted = false
        try {
            if (token != null) delay(FLAG_SETTLE_MS)
            if (gate?.awaitGestureAccess() == false) return ActionResult.Cancelled("User is interacting with PocketPilot controls")
            if (!isScreenAvailable(service)) return ActionResult.Failure("Unlock the phone to continue.")
            if (gate?.isGesturePathClear() == false) return ActionResult.Failure("Move the PocketPilot bubble clear of the target and try again.")
            visualize()
            val result = withTimeoutOrNull(GESTURE_TIMEOUT_MS) {
                suspendCancellableCoroutine<ActionResult> { continuation ->
                    val callback =
                            object : AccessibilityService.GestureResultCallback() {
                                override fun onCompleted(gestureDescription: GestureDescription?) {
                                    Log.d(TAG, "dispatchGesture completed")
                                    if (continuation.isActive) {
                                        continuation.resume(ActionResult.Success("Gesture completed"))
                                    }
                                }

                                override fun onCancelled(gestureDescription: GestureDescription?) {
                                    Log.w(TAG, "dispatchGesture cancelled")
                                    interrupted = true
                                    if (continuation.isActive) {
                                        continuation.resume(ActionResult.Failure("Gesture interrupted. Observe the screen before retrying."))
                                    }
                                }
                            }

                    val dispatched = service.dispatchGesture(gesture, callback, null)
                    Log.d(TAG, "dispatchGesture dispatched=$dispatched, ${describeGesture(gesture)}")
                    if (!dispatched && continuation.isActive) {
                        continuation.resume(ActionResult.Failure("Failed to dispatch gesture"))
                    }
                }
            }
                ?: ActionResult.Failure("Gesture timed out after ${GESTURE_TIMEOUT_MS}ms")
            completed = result is ActionResult.Success
            if (interrupted) {
                visualizer?.hide()
                val released = token
                token = null
                released?.close()
                if (gate?.awaitGestureAccess() == false) return ActionResult.Cancelled("User took control during the gesture")
            }
            return result
        } finally {
            if (!completed) visualizer?.hide()
            token?.close()
        }
    }

    private fun buildGesture(stroke: GestureDescription.StrokeDescription): GestureDescription {
        return GestureDescription.Builder().addStroke(stroke).build()
    }

    private fun describeGesture(gesture: GestureDescription): String {
        val parts = mutableListOf<String>()
        val pos = FloatArray(2)
        val pathMeasure = PathMeasure()
        for (i in 0 until gesture.strokeCount) {
            val stroke = gesture.getStroke(i)
            val path = stroke.path
            pathMeasure.setPath(path, false)
            val length = pathMeasure.length
            val hasStart = pathMeasure.getPosTan(0f, pos, null)
            val startX = if (hasStart) pos[0] else Float.NaN
            val startY = if (hasStart) pos[1] else Float.NaN
            val hasEnd = pathMeasure.getPosTan(length, pos, null)
            val endX = if (hasEnd) pos[0] else Float.NaN
            val endY = if (hasEnd) pos[1] else Float.NaN
            parts +=
                    "#$i(start=${stroke.startTime},dur=${stroke.duration},len=${"%.1f".format(length)}," +
                            "from=${"%.1f".format(startX)},${"%.1f".format(startY)}," +
                            "to=${"%.1f".format(endX)},${"%.1f".format(endY)})"
        }
        return parts.joinToString(";")
    }
}
