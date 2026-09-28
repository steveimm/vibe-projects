package id.steveimm.pocketpilot.platform

/** Gate that temporarily makes the capsule overlay non-touchable during gesture dispatch. */
interface OverlayTouchGate {
    /** Enter gesture pass-through mode. The overlay becomes [FLAG_NOT_TOUCHABLE]. Call [AutoCloseable.close] when the gesture completes
     * (or in a `finally` block). */
    fun beginGesturePassThrough(): AutoCloseable
}
