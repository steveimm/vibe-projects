package id.steveimm.pocketpilot.platform

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

data class GestureCoordinates(
    val startX: Float,
    val startY: Float,
    val endX: Float = startX,
    val endY: Float = startY,
) {
    fun intersects(left: Float, top: Float, right: Float, bottom: Float): Boolean {
        if (max(startX, endX) < left || min(startX, endX) > right ||
            max(startY, endY) < top || min(startY, endY) > bottom) return false
        val normalX = startY - endY
        val normalY = endX - startX
        val distance = abs(normalX * (startX - (left + right) / 2) + normalY * (startY - (top + bottom) / 2))
        return distance <= abs(normalX) * (right - left) / 2 + abs(normalY) * (bottom - top) / 2
    }
}
