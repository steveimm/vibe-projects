package id.steveimm.pocketpilot.ui.overlay.compose

import android.accessibilityservice.AccessibilityService
import android.graphics.PixelFormat
import android.os.SystemClock
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.LifecycleOwner
import androidx.savedstate.SavedStateRegistryOwner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicLong

class VisualizerOverlayHost(
    private val service: AccessibilityService,
    lifecycleOwner: LifecycleOwner,
    savedStateRegistryOwner: SavedStateRegistryOwner,
) {
    companion object {
        private const val TAG = "VisualizerOverlayHost"
        private const val CLICK_DURATION_MS = 500L
        private const val SWIPE_EXTRA_DURATION_MS = 400L
    }

    private val windowManager = service.getSystemService(WindowManager::class.java)
    private val composeHost = OverlayComposeHost(
        context = service,
        lifecycleOwner = lifecycleOwner,
        savedStateRegistryOwner = savedStateRegistryOwner,
        windowManager = windowManager,
        tag = TAG,
    )
    private val scope = CoroutineScope(Dispatchers.Main.immediate + SupervisorJob())
    private val items = MutableStateFlow<List<VisualizationItem>>(emptyList())
    private val nextId = AtomicLong(1)

    private var disposed = false

    fun suppressForScreenshot(): AutoCloseable = composeHost.suppressForScreenshot()

    fun showClick(x: Float, y: Float, longPress: Boolean) {
        if (disposed) return
        ensureOverlay()
        val item = VisualizationItem.Click(
            id = nextId.getAndIncrement(),
            createdAtMs = SystemClock.uptimeMillis(),
            durationMs = CLICK_DURATION_MS,
            x = x,
            y = y,
            longPress = longPress,
        )
        addItem(item)
    }

    fun showSwipe(
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        durationMs: Long,
    ) {
        if (disposed) return
        ensureOverlay()
        val item = VisualizationItem.Swipe(
            id = nextId.getAndIncrement(),
            createdAtMs = SystemClock.uptimeMillis(),
            durationMs = durationMs + SWIPE_EXTRA_DURATION_MS,
            startX = startX,
            startY = startY,
            endX = endX,
            endY = endY,
        )
        addItem(item)
    }

    fun hide() {
        items.value = emptyList()
        composeHost.hide()
    }

    fun dispose() {
        disposed = true
        hide()
        composeHost.dispose()
        scope.cancel()
    }

    private fun ensureOverlay() {
        if (composeHost.isShowing()) return
        composeHost.show(createLayoutParams()) {
            val renderItems by items.collectAsState(initial = emptyList())
            ActionVisualizerCompose(items = renderItems)
        }
        Log.d(TAG, "Visualizer overlay shown")
    }

    private fun addItem(item: VisualizationItem) {
        items.update { it + item }
        scope.launch {
            delay(item.durationMs)
            items.update { list -> list.filterNot { it.id == item.id } }
        }
    }

    private fun createLayoutParams(): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            setFitInsetsTypes(0)
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
        }
    }
}
