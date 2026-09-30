package id.steveimm.pocketpilot.ui.overlay.compose

import android.animation.ValueAnimator
import android.content.Context
import android.util.Log
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.lifecycle.LifecycleOwner
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import id.steveimm.pocketpilot.ui.theme.PocketPilotMotion
import id.steveimm.pocketpilot.ui.theme.PocketPilotTheme

class OverlayComposeHost(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val savedStateRegistryOwner: SavedStateRegistryOwner,
    private val windowManager: WindowManager,
    private val tag: String,
    private val animateVisibility: Boolean = false,
) {
    private var root: FrameLayout? = null
    private var composeView: ComposeView? = null
    private var params: WindowManager.LayoutParams? = null
    private var screenshotDepth = 0
    private var hiding = false

    fun isShowing(): Boolean = root != null && !hiding

    fun show(layoutParams: WindowManager.LayoutParams, content: @Composable () -> Unit) {
        if (isShowing()) return
        remove()
        try {
            val container = FrameLayout(context).apply {
                alpha = if (screenshotDepth > 0) 0f else 1f
                setViewTreeLifecycleOwner(lifecycleOwner)
                setViewTreeSavedStateRegistryOwner(savedStateRegistryOwner)
            }
            val view = ComposeView(context).apply {
                setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
                setContent { PocketPilotTheme { content() } }
            }
            container.addView(view, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, layoutParams.height))
            val animate = animateVisibility && ValueAnimator.areAnimatorsEnabled()
            if (animate) {
                view.alpha = 0f
                view.translationY = 12 * context.resources.displayMetrics.density
            }
            windowManager.addView(container, layoutParams)
            root = container
            composeView = view
            params = layoutParams
            if (animate) view.animate().alpha(1f).translationY(0f)
                .setDuration(PocketPilotMotion.Standard.toLong()).setInterpolator(DecelerateInterpolator()).start()
        } catch (e: Exception) {
            Log.e(tag, "Failed to show Compose overlay", e)
            remove()
        }
    }

    fun suppressForScreenshot(): AutoCloseable {
        screenshotDepth++
        root?.alpha = 0f
        var closed = false
        return AutoCloseable {
            if (!closed) {
                closed = true
                screenshotDepth--
                root?.alpha = if (screenshotDepth > 0) 0f else 1f
            }
        }
    }

    fun hide() {
        if (!isShowing()) return
        if (!animateVisibility || !ValueAnimator.areAnimatorsEnabled()) {
            remove()
            return
        }
        hiding = true
        updateLayoutParams {
            it.flags = it.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        }
        composeView?.animate()?.cancel()
        composeView?.animate()?.alpha(0f)?.translationY(8 * context.resources.displayMetrics.density)
            ?.setDuration(PocketPilotMotion.Quick.toLong())?.withEndAction { remove() }?.start()
    }

    private fun remove() {
        composeView?.animate()?.withEndAction(null)?.cancel()
        root?.let { view ->
            try { windowManager.removeViewImmediate(view) }
            catch (e: Exception) { Log.w(tag, "Failed to remove Compose overlay", e) }
        }
        root = null
        composeView = null
        params = null
        hiding = false
    }

    fun updateLayoutParams(update: (WindowManager.LayoutParams) -> Unit) {
        val view = root ?: return
        val layoutParams = params ?: return
        update(layoutParams)
        composeView?.let { child ->
            if (child.layoutParams.height != layoutParams.height) {
                child.layoutParams = child.layoutParams.apply { height = layoutParams.height }
            }
        }
        try { windowManager.updateViewLayout(view, layoutParams) }
        catch (e: Exception) { Log.w(tag, "Failed to update Compose overlay params", e) }
    }

    fun topOnScreen(): Int = root?.let {
        val position = IntArray(2)
        it.getLocationOnScreen(position)
        position[1]
    } ?: 0

    fun getWindowToken() = root?.windowToken
    fun dispose() { remove() }
}
