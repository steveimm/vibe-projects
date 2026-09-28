package id.steveimm.pocketpilot.platform.virtualdisplay

import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.InputEvent
import android.view.Surface
import id.steveimm.pocketpilot.platform.ShizukuShell
import rikka.shizuku.Shizuku

/** ShizukuClient — Thin wrapper for Shizuku binder calls. */
class ShizukuClient {

    companion object {
        private const val TAG = "ShizukuClient"

        /** InputManager.INJECT_INPUT_EVENT_MODE_WAIT_FOR_FINISH */
        const val INJECT_MODE_WAIT = 2
    }

    private val runtimeGateway = ShizukuRuntimeGateway()

    /** True if Shizuku binder is alive and responding. */
    fun isAvailable(): Boolean =
            runtimeGateway.isAvailable()

    /** True if we have been granted Shizuku permission. */
    fun hasPermission(): Boolean =
            runtimeGateway.hasPermission()

    /** Request Shizuku permission from the user. */
    fun requestPermission(requestCode: Int) {
        runtimeGateway.requestPermission(requestCode)
    }

    /** Register a listener for Shizuku binder death. */
    fun addBinderDeadListener(listener: Shizuku.OnBinderDeadListener) {
        runtimeGateway.addBinderDeadListener(listener)
    }

    /** Remove a previously registered binder death listener. */
    fun removeBinderDeadListener(listener: Shizuku.OnBinderDeadListener) {
        runtimeGateway.removeBinderDeadListener(listener)
    }

    /** Register a listener for Shizuku permission request results. */
    fun addRequestPermissionResultListener(listener: Shizuku.OnRequestPermissionResultListener) {
        runtimeGateway.addRequestPermissionResultListener(listener)
    }

    /** Remove a previously registered permission result listener. */
    fun removeRequestPermissionResultListener(listener: Shizuku.OnRequestPermissionResultListener) {
        runtimeGateway.removeRequestPermissionResultListener(listener)
    }

    /** Exempt all hidden APIs for this process. Must be called before any reflection on framework internals. */
    fun bypassHiddenApis() {
        runtimeGateway.bypassHiddenApis()
    }

    private val proxyProvider = ShizukuServiceProxyProvider()
    private val displayTransport = ShizukuDisplayTransport(proxyProvider)
    private val inputTransport = ShizukuInputTransport(proxyProvider)
    private val activityTaskTransport = ShizukuActivityTaskTransport(proxyProvider)
    private val activityLauncher = ShizukuActivityLauncher()

    /** Create a virtual display via IDisplayManager through Shizuku. */
    fun createVirtualDisplay(
            name: String,
            width: Int,
            height: Int,
            densityDpi: Int,
            surface: Surface,
            flags: Int
    ): Int {
        return displayTransport.createVirtualDisplay(name, width, height, densityDpi, surface, flags)
    }

    /** Switch the surface a virtual display renders to. */
    fun setVirtualDisplaySurface(displayId: Int, surface: Surface): Boolean {
        return displayTransport.setVirtualDisplaySurface(displayId, surface)
    }

    /** Release a virtual display. */
    fun releaseVirtualDisplay(displayId: Int) {
        displayTransport.releaseVirtualDisplay(displayId)
    }

    /** Remove root tasks currently attached to a display before releasing that display. */
    fun removeRootTasksOnDisplay(displayId: Int): Int {
        return activityTaskTransport.removeRootTasksOnDisplay(displayId)
    }

    /** Inject an input event via IInputManager through Shizuku. */
    fun injectInputEvent(event: InputEvent, mode: Int = INJECT_MODE_WAIT): Boolean {
        return inputTransport.injectInputEvent(event, mode)
    }

    /** Launch an activity on a specific display. */
    fun launchOnDisplay(context: Context, intent: Intent, displayId: Int) {
        activityLauncher.launchOnDisplay(context, intent, displayId)
    }

    /** Execute a shell command via Shizuku. */
    fun executeShellCommand(command: Array<String>): Int {
        return ShizukuShell.execute(command, timeoutSec = 30L).exitCode
    }

    /** Clear cached binder proxies. Call during platform stop/cleanup. Safe to call even if proxies were never created. */
    fun clearCachedProxies() {
        proxyProvider.clear()
        displayTransport.clear()
        Log.d(TAG, "Cleared cached binder proxies")
    }

}
