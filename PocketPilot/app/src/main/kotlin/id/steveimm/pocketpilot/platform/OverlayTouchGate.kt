package id.steveimm.pocketpilot.platform

/** Temporarily suppress overlay touches or rendering during phone actions and observations. */
interface OverlayTouchGate {
    /** Enter gesture pass-through mode. The overlay becomes [FLAG_NOT_TOUCHABLE]. Call [AutoCloseable.close] when the gesture completes
     * (or in a `finally` block). */
    fun beginGesturePassThrough(): AutoCloseable

    fun beginScreenshotCapture(): AutoCloseable = AutoCloseable {}
}
