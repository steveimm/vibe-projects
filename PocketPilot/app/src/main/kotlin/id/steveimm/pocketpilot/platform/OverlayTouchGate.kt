package id.steveimm.pocketpilot.platform

import kotlinx.coroutines.delay

/** Temporarily suppress overlay touches or rendering during phone actions and observations. */
interface OverlayTouchGate {
    fun canInjectGesture(): Boolean = true
    fun isUserTouchActive(): Boolean = false
    fun isGesturePathClear(): Boolean = true

    suspend fun awaitGestureAccess(): Boolean {
        while (canInjectGesture()) {
            if (!isUserTouchActive()) return true
            delay(16)
        }
        return false
    }

    /** Move controls clear of the gesture and temporarily pass through any interaction shield. */
    fun beginGesturePassThrough(gesture: GestureCoordinates): AutoCloseable

    fun beginScreenshotCapture(): AutoCloseable = AutoCloseable {}
}
