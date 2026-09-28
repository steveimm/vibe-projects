package id.steveimm.pocketpilot.platform

import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.protocol.PlatformMode

/** AndroidPlatform - Abstraction for Android-specific operations. */
interface AndroidPlatform {

    /** Which platform implementation this is. AccessibilityPlatform vs. VirtualDisplayPlatform must be distinguishable so the UI can
     * render the effective mode of the live session (which may diverge from the persisted intent when PlatformFactory falls back). */
    val mode: PlatformMode

    /** Initialize platform resources. */
    suspend fun start() {}

    /** Release platform resources. */
    suspend fun stop() {}

    /** Capture the current screen state. */
    suspend fun captureScreen(): ScreenSnapshot

    /** Perform an atomic UI action on the device. */
    suspend fun performAction(action: UIAction): ActionResult

    /** Check if the platform has all required permissions. */
    fun hasRequiredPermissions(): Boolean

    /** Get the current package name of the foreground app. */
    fun getCurrentPackageName(): String?

    /** Get display metrics. */
    fun getDisplayInfo(): DisplayInfo

    // Platform Capabilities

    /** Whether tap-to-focus fallback is safe for text input. */
    fun allowTapToFocus(): Boolean = true

    /** Show visual feedback for a verified native scroll action. */
    fun showScrollVisualization(x: Int, y: Int, direction: String) {}

    // App Management (P0)

    /** Get list of installed launchable apps. */
    suspend fun getInstalledApps(): List<AppInfo>

    /** Launch an app by package name. */
    suspend fun launchApp(packageName: String): ActionResult
}

/** DisplayInfo - Information about the device display. */
data class DisplayInfo(
    val widthPixels: Int,
    val heightPixels: Int,
    val density: Float
)

/** AppInfo - Information about an installed app. */
data class AppInfo(
    val packageName: String,
    val label: String,
    val isSystemApp: Boolean = false
)
