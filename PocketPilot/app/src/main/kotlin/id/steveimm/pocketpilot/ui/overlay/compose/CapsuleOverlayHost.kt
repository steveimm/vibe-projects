package id.steveimm.pocketpilot.ui.overlay.compose

import android.accessibilityservice.AccessibilityService
import android.content.ComponentCallbacks
import android.content.res.Configuration
import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.util.Log
import android.view.Gravity
import android.view.View
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.fillMaxSize
import android.view.WindowInsets
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.Toast
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.widthIn
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.Modifier
import androidx.lifecycle.LifecycleOwner
import androidx.savedstate.SavedStateRegistryOwner
import id.steveimm.pocketpilot.app.AgentService
import id.steveimm.pocketpilot.protocol.ApprovalDecision
import id.steveimm.pocketpilot.protocol.ApprovalScope
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.ui.capsule.NavAction
import id.steveimm.pocketpilot.ui.capsule.surface.LocalVoiceFeedback
import id.steveimm.pocketpilot.ui.capsule.surface.SmartCapsuleSurface
import id.steveimm.pocketpilot.ui.capsule.surface.VoiceMicDeps
import id.steveimm.pocketpilot.ui.capsule.surface.smartCapsuleHostPadding
import id.steveimm.pocketpilot.ui.capsule.voice.AndroidRecognizerFactory
import id.steveimm.pocketpilot.platform.OverlayTouchGate
import id.steveimm.pocketpilot.platform.GestureCoordinates
import id.steveimm.pocketpilot.ui.overlay.CapsuleStateHolder
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

class CapsuleOverlayHost(
    private val service: AccessibilityService,
    private val stateHolder: CapsuleStateHolder,
    private val scope: CoroutineScope,
    lifecycleOwner: LifecycleOwner,
    savedStateRegistryOwner: SavedStateRegistryOwner,
) {
    companion object {
        private const val TAG = "CapsuleOverlayHost"
        private const val DEBOUNCE_MS = 300L
    }

    var onTakeover: (() -> Unit)? = null
    var onResume: (() -> Unit)? = null
    var onSupplement: ((String) -> Unit)? = null
    var onSupplementAndResume: ((String) -> Unit)? = null
    var onUserResponse: ((String, String) -> Unit)? = null
    var onApprovalResponse: ((String, ApprovalDecision, ApprovalScope, String) -> Unit)? = null
    var onStop: (() -> Unit)? = null
    var onOpenApp: (() -> Unit)? = null
    var onNewConversation: (() -> Unit)? = null
    var onCloseOverlay: (() -> Unit)? = null
    var onOpenViewer: (() -> Unit)? = null
    var onSend: ((String) -> Unit)? = null

    private val windowManager = service.getSystemService(WindowManager::class.java)
    private val composeHost = OverlayComposeHost(
        context = service,
        lifecycleOwner = lifecycleOwner,
        savedStateRegistryOwner = savedStateRegistryOwner,
        windowManager = windowManager,
        tag = TAG,
        animateVisibility = true,
    )

    private val interactionLocked = MutableStateFlow(false)
    private val inputFocused = MutableStateFlow(false)

    private var focusJob: Job? = null
    private var lastButtonClickTime = 0L
    private var isFocusable = false
    private val gestureLeases = mutableListOf<GestureCoordinates>()
    private var gestureSuppression: AutoCloseable? = null
    private val configurationCallback = object : ComponentCallbacks {
        override fun onConfigurationChanged(newConfig: Configuration) { updateWindowBounds() }
        override fun onLowMemory() = Unit
    }

    /** Gate for [AccessibilityGestureInjector] to temporarily pass touches through. */
    val touchGate: OverlayTouchGate = object : OverlayTouchGate {
        override fun beginGesturePassThrough(gesture: GestureCoordinates): AutoCloseable {
            gestureLeases.add(gesture)
            if (!composeHost.isShowing()) composeHost.hideImmediately()
            updateGesturePassThrough()
            var closed = false
            return AutoCloseable {
                if (closed) return@AutoCloseable
                closed = true
                gestureLeases.remove(gesture)
                updateGesturePassThrough()
            }
        }
    }

    fun suppressForScreenshot(): AutoCloseable = composeHost.suppressForScreenshot()

    fun isShowing(): Boolean = composeHost.isShowing()

    fun show() {
        if (composeHost.isShowing()) return
        setGesturePassThrough(gestureLeases.isNotEmpty())
        composeHost.show(createLayoutParams(interactionLocked.value)) {
            val mode by stateHolder.mode.collectAsState(initial = CapsuleMode.Hidden)
            val stopPending by stateHolder.isStopPending.collectAsState(initial = false)
            val lastToolCall by stateHolder.lastToolCall.collectAsState()
            val ctx by stateHolder.context.collectAsState()
            val platform by stateHolder.platformMode.collectAsState()
            val lockTouches by interactionLocked.collectAsState(initial = false)

            val capsuleContent: @androidx.compose.runtime.Composable () -> Unit = {
                val overlayContext = LocalContext.current
                val voiceDeps = remember {
                    val appCtx = service.applicationContext
                    object : VoiceMicDeps {
                        override val factory = AndroidRecognizerFactory(appCtx)
                        override val activity: android.app.Activity? = null
                        override fun isPermissionGranted(): Boolean =
                            androidx.core.content.ContextCompat.checkSelfPermission(
                                appCtx,
                                android.Manifest.permission.RECORD_AUDIO,
                            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        override fun requestOverlayPermission() {
                            AgentService.instance?.requestVoicePermissionViaMainActivity()
                        }
                    }
                }
                CompositionLocalProvider(
                    LocalVoiceFeedback provides { message ->
                        Toast.makeText(
                            overlayContext.applicationContext,
                            message,
                            Toast.LENGTH_SHORT,
                        ).show()
                    },
                ) {
                    SmartCapsuleSurface(
                        modifier = Modifier.onGloballyPositioned { updateGesturePassThrough() },
                        mode = mode,
                        inputDraft = if (mode is CapsuleMode.WaitingForInput) stateHolder.responseDraft else stateHolder.inputDraft,
                        isStopPending = stopPending,
                        lastToolCall = lastToolCall,
                        platformMode = platform,
                        context = ctx,
                        onSend = { text -> debounced { onSend?.invoke(text) } },
                        onSupplement = { text -> debounced { onSupplement?.invoke(text) } },
                        onTakeover = { debounced { onTakeover?.invoke() } },
                        onResume = { debounced { onResume?.invoke() } },
                        onSupplementAndResume = { text ->
                            debounced {
                                val submit = onSupplementAndResume
                                if (submit != null) {
                                    submit(text)
                                } else {
                                    onSupplement?.invoke(text)
                                    onResume?.invoke()
                                }
                            }
                        },
                        onStop = { debounced { onStop?.invoke() } },
                        onUserResponse = { callId, response ->
                            debounced { onUserResponse?.invoke(callId, response) }
                        },
                        onApprovalResponse = { callId, decision, scope, packageName ->
                            debounced { onApprovalResponse?.invoke(callId, decision, scope, packageName) }
                        },
                        onNavigate = { action ->
                            debounced {
                                when (action) {
                                    NavAction.NEW_CONVERSATION -> onNewConversation?.invoke()
                                    NavAction.CLOSE_OVERLAY -> onCloseOverlay?.invoke()
                                    NavAction.OPEN_APP -> onOpenApp?.invoke()
                                    NavAction.OPEN_VIEWER -> onOpenViewer?.invoke()
                                }
                            }
                        },
                        onInputFocusChanged = { focused -> inputFocused.value = focused },
                        onInputSubmitted = {
                            inputFocused.value = false
                            setOverlayFocusable(false)
                        },
                        autoFocusInput = mode is CapsuleMode.WaitingForInput,
                        voice = voiceDeps,
                    )
                }
            }


            if (lockTouches) {
                Box(modifier = Modifier.fillMaxSize()) {
                    AndroidView(
                        factory = { ctx ->
                            View(ctx).apply {
                                setOnTouchListener { _, _ -> true }
                            }
                        },
                        modifier = Modifier
                            .fillMaxSize()
                    )
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .widthIn(max = 420.dp)
                            .fillMaxWidth()
                            .imePadding()
                            .navigationBarsPadding()
                            .smartCapsuleHostPadding()
                    ) {
                        capsuleContent()
                    }
                }
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .smartCapsuleHostPadding()
                ) {
                    capsuleContent()
                }
            }
        }
        updateGesturePassThrough()
        if (composeHost.isShowing()) service.registerComponentCallbacks(configurationCallback)
        startFocusObserver()
        Log.i(TAG, "Capsule overlay shown")
    }

    fun hide(immediate: Boolean = false) {
        if (composeHost.isShowing()) service.unregisterComponentCallbacks(configurationCallback)
        stopFocusObserver()
        inputFocused.value = false
        setOverlayFocusable(false)
        if (immediate || gestureLeases.isNotEmpty()) composeHost.hideImmediately() else composeHost.hide()
        setGesturePassThrough(false)
    }

    fun dispose() {
        hide()
        composeHost.dispose()
        gestureLeases.clear()
    }

    fun setInteractionLocked(locked: Boolean) {
        if (interactionLocked.value == locked) return
        interactionLocked.value = locked
        updateWindowBounds()
    }

    private fun updateWindowBounds() {
        composeHost.updateLayoutParams { configureBounds(it, interactionLocked.value) }
        updateGesturePassThrough()
    }

    private fun configureBounds(params: WindowManager.LayoutParams, locked: Boolean) {
        params.width = if (locked) WindowManager.LayoutParams.MATCH_PARENT
            else (420 * service.resources.displayMetrics.density).toInt().coerceAtMost(windowManager.maximumWindowMetrics.bounds.width())
        params.height = if (locked) WindowManager.LayoutParams.MATCH_PARENT else WindowManager.LayoutParams.WRAP_CONTENT
        params.gravity = if (locked) Gravity.TOP or Gravity.START else Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        params.setFitInsetsTypes(if (locked) WindowInsets.Type.systemBars()
            else WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout() or WindowInsets.Type.ime())
    }

    private fun startFocusObserver() {
        focusJob?.cancel()
        focusJob = scope.launch {
            combine(stateHolder.mode, inputFocused) { mode, focused ->
                when (mode) {
                    is CapsuleMode.WaitingForInput -> true
                    is CapsuleMode.Done, is CapsuleMode.Hidden, is CapsuleMode.Error -> true
                    is CapsuleMode.Takeover -> focused
                    else -> false
                }
            }.collect { shouldBeFocusable ->
                setOverlayFocusable(shouldBeFocusable)
            }
        }
    }

    private fun stopFocusObserver() {
        focusJob?.cancel()
        focusJob = null
    }

    private fun setOverlayFocusable(focusable: Boolean) {
        if (isFocusable == focusable || !composeHost.isShowing()) return
        isFocusable = focusable
        composeHost.updateLayoutParams { params ->
            params.flags = if (focusable) {
                params.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()
            } else {
                params.flags or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
            }
        }
        if (!focusable) {
            val imm = service.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.hideSoftInputFromWindow(composeHost.getWindowToken(), 0)
        }
    }

    private fun createLayoutParams(locked: Boolean): WindowManager.LayoutParams =
        WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            if (locked) WindowManager.LayoutParams.MATCH_PARENT
            else WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                (if (gestureSuppression != null) WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE else 0),
            PixelFormat.TRANSLUCENT
        ).apply {
            title = "PocketPilot controls"
            configureBounds(this, locked)
        }

    private fun updateGesturePassThrough() {
        val bounds = composeHost.boundsOnScreen()
        val passThrough = composeHost.isShowing() && gestureLeases.isNotEmpty() &&
            (interactionLocked.value || bounds == null || gestureLeases.any {
                it.intersects(bounds.left.toFloat(), bounds.top.toFloat(), bounds.right.toFloat(), bounds.bottom.toFloat())
            })
        setGesturePassThrough(passThrough)
    }

    private fun setGesturePassThrough(enabled: Boolean) {
        if (enabled == (gestureSuppression != null)) return
        if (enabled) {
            Log.d(TAG, "Hiding controls for an overlapping gesture")
            gestureSuppression = composeHost.suppressRendering()
        }
        if (composeHost.isShowing()) {
            composeHost.updateLayoutParams { params ->
                params.flags = if (enabled) params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                    else params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
            }
        }
        if (!enabled) {
            gestureSuppression?.close()
            gestureSuppression = null
            Log.d(TAG, "Restored controls after gesture")
        }
    }

    private fun debounced(action: () -> Unit) {
        val now = System.currentTimeMillis()
        if (now - lastButtonClickTime < DEBOUNCE_MS) return
        lastButtonClickTime = now
        action()
    }
}
