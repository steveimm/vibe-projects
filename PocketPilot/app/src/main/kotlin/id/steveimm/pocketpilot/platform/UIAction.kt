package id.steveimm.pocketpilot.platform

import id.steveimm.pocketpilot.model.Bounds

/** Identity snapshot of the intended target element from perception. */
data class SemanticTargetHint(
    val resourceId: String,
    val text: String,
    val description: String,
    val className: String,
    val bounds: Bounds
)

/** UIAction - Platform-agnostic representation of UI actions. */
sealed interface UIAction {

    /** Perform ACTION_CLICK on the clickable accessibility node at coordinates. */
    data class ClickNodeAt(
        val x: Int,
        val y: Int,
        val semanticHint: SemanticTargetHint? = null
    ) : UIAction

    /** Perform a gesture tap at coordinates. */
    data class TapAt(
        val x: Int,
        val y: Int
    ) : UIAction

    /** Find node at (x,y), perform ACTION_LONG_CLICK */
    data class LongClickNodeAt(
        val x: Int,
        val y: Int,
        val semanticHint: SemanticTargetHint? = null
    ) : UIAction

    /** Find node at (x,y), perform ACTION_SET_TEXT */
    data class SetTextOnNodeAt(
        val x: Int, val y: Int,
        val text: String, val clear: Boolean = false
    ) : UIAction

    /** Find focused editable node, perform ACTION_SET_TEXT */
    data class SetTextOnFocused(
        val text: String, val clear: Boolean = false
    ) : UIAction

    /** Gesture long press (hold) at coordinates for duration */
    data class LongPressAt(
        val x: Int, val y: Int,
        val durationMs: Long
    ) : UIAction

    /** Perform a scroll action on the scrollable node at coordinates. */
    data class ScrollNodeAt(
        val x: Int,
        val y: Int,
        val direction: String
    ) : UIAction

    /** Swipe from one point to another. Gesture-only, no node actions. */
    data class Swipe(
        val startX: Int,
        val startY: Int,
        val endX: Int,
        val endY: Int,
        val durationMs: Long = 300
    ) : UIAction

    /** Press a system button. */
    data class SystemButton(
        val button: SystemButtonType
    ) : UIAction

}

/** SystemButtonType - System buttons that can be pressed. */
enum class SystemButtonType {
    BACK,
    HOME,
    RECENTS,
    ENTER  // Enter/Return key
}
