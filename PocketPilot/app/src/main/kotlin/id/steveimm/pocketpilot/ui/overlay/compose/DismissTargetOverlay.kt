package id.steveimm.pocketpilot.ui.overlay.compose

import android.accessibilityservice.AccessibilityService
import android.graphics.PixelFormat
import android.graphics.PointF
import android.view.Gravity
import android.view.WindowInsets
import android.view.WindowManager
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import androidx.lifecycle.LifecycleOwner
import androidx.savedstate.SavedStateRegistryOwner
import id.steveimm.pocketpilot.ui.theme.PocketPilotMotion
import id.steveimm.pocketpilot.ui.theme.pocketPilot
import kotlin.math.hypot
import kotlin.math.roundToInt

internal class DismissTargetOverlay(
    private val service: AccessibilityService,
    lifecycleOwner: LifecycleOwner,
    savedStateRegistryOwner: SavedStateRegistryOwner,
) {
    private val manager = service.getSystemService(WindowManager::class.java)
    private val host = OverlayComposeHost(
        service, lifecycleOwner, savedStateRegistryOwner, manager, "DismissTargetOverlay", animateVisibility = true,
    )
    private val highlighted = mutableStateOf(false)
    var center = PointF()
        private set

    fun show() {
        val metrics = manager.currentWindowMetrics
        val insets = metrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
        val size = dp(96)
        center = PointF((insets.left + metrics.bounds.width() - insets.right) / 2f,
            (metrics.bounds.height() - insets.bottom - dp(64)).toFloat())
        val params = WindowManager.LayoutParams(size, size, WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN, PixelFormat.TRANSLUCENT).apply {
            title = "PocketPilot dismiss target"
            @Suppress("RtlHardcoded")
            gravity = Gravity.TOP or Gravity.LEFT
            x = (center.x - size / 2).roundToInt()
            y = (center.y - size / 2).roundToInt()
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            setFitInsetsTypes(0)
        }
        highlighted.value = false
        host.show(params) {
            val active by highlighted
            val scale by animateFloatAsState(if (active) 1.15f else 1f,
                tween(if (PocketPilotMotion.reducedMotion()) 0 else PocketPilotMotion.Quick), label = "Dismiss target")
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Surface(Modifier.size(56.dp).graphicsLayer { scaleX = scale; scaleY = scale }, shape = CircleShape,
                    color = if (active) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.surfaceContainerHigh,
                    border = BorderStroke(1.dp, if (active) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.outlineVariant),
                    shadowElevation = MaterialTheme.pocketPilot.elevation.floating) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.Close, "Dismiss PocketPilot", Modifier.size(24.dp),
                            tint = if (active) MaterialTheme.colorScheme.onError else MaterialTheme.colorScheme.onSurface)
                    }
                }
            }
        }
    }

    fun contains(x: Float, y: Float): Boolean = host.isShowing() && hypot(x - center.x, y - center.y) <= dp(64)
    fun highlight(value: Boolean) { highlighted.value = value }
    fun hide(immediate: Boolean = false) {
        highlighted.value = false
        if (immediate) host.hideImmediately() else host.hide()
    }
    fun suppressForScreenshot(): AutoCloseable = host.suppressForScreenshot()
    private fun dp(value: Int): Int = (value * service.resources.displayMetrics.density).roundToInt()
}
