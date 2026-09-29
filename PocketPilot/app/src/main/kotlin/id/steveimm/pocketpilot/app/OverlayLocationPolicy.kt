package id.steveimm.pocketpilot.app

import android.view.Display
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleContext
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode

internal enum class OverlayUserLocation {
    MAIN_APP,
    VD_VIEWER,
    OTHER_APP
}

internal enum class ShowPreference {
    CAPSULE,
    BUBBLE
}

internal data class OverlayVisibilityDecision(
    val showCapsule: Boolean,
    val showBubble: Boolean,
    val showGlow: Boolean,
)

internal fun isActivityWindowClass(className: String?): Boolean {
    val name = className?.substringBefore('$') ?: return false
    if (name.startsWith("android.widget.") ||
        name.startsWith("android.view.") ||
        name.startsWith("android.app.") ||
        name.startsWith("android.inputmethodservice.") ||
        name.startsWith("androidx.") ||
        name.contains("inputmethod", ignoreCase = true)) return false
    return name.contains('.')
}

internal fun resolveUserLocation(
    appPackage: String,
    packageName: String?,
    className: String?,
    displayId: Int? = null,
): OverlayUserLocation? {
    if (!isActivityWindowClass(className)) return null
    if (packageName == null) return null
    // Ignore non-default display activity windows to prevent VD app windows from
    // flipping location while user stays in MainActivity on the real screen.
    if (displayId != null && displayId != Display.DEFAULT_DISPLAY) return null
    if (packageName != appPackage) return OverlayUserLocation.OTHER_APP

    val normalizedClassName = className?.substringBefore('$') ?: return null
    // Release builds obfuscate Compose window classes, so package/prefix checks are insufficient.
    return when (normalizedClassName) {
        "$appPackage.ui.viewer.VirtualDisplayViewerActivity" -> OverlayUserLocation.VD_VIEWER
        "$appPackage.app.MainActivity" -> OverlayUserLocation.MAIN_APP
        else -> null
    }
}

internal fun resolveCapsuleContext(
    platformMode: PlatformMode,
    location: OverlayUserLocation,
): CapsuleContext =
    when (platformMode) {
        PlatformMode.ACCESSIBILITY -> {
            if (location == OverlayUserLocation.MAIN_APP) CapsuleContext.MAIN_APP
            else CapsuleContext.SCREEN_VIEWING
        }
        PlatformMode.VIRTUAL_DISPLAY -> {
            when (location) {
                OverlayUserLocation.MAIN_APP -> CapsuleContext.MAIN_APP
                OverlayUserLocation.VD_VIEWER -> CapsuleContext.SCREEN_VIEWING
                OverlayUserLocation.OTHER_APP -> CapsuleContext.BACKGROUND
            }
        }
    }

/** Compute the new userLocation when MainActivity.onStop fires. */
internal fun resolveLocationOnMainAppHidden(
    current: OverlayUserLocation,
): OverlayUserLocation = when (current) {
    OverlayUserLocation.MAIN_APP -> OverlayUserLocation.OTHER_APP
    OverlayUserLocation.VD_VIEWER -> OverlayUserLocation.VD_VIEWER
    OverlayUserLocation.OTHER_APP -> OverlayUserLocation.OTHER_APP
}

/** Whether the VirtualDisplayViewerActivity should auto-finish so the user is returned to MainActivity instead of being stranded on a
 * frozen, non-interactive VD surface. */
internal fun shouldFinishViewerOnIdle(
    platformMode: PlatformMode,
    location: OverlayUserLocation,
    mode: CapsuleMode,
    hasActiveTask: Boolean,
): Boolean = platformMode == PlatformMode.VIRTUAL_DISPLAY &&
    location == OverlayUserLocation.VD_VIEWER &&
    !hasActiveTask &&
    mode is CapsuleMode.Hidden

internal fun deriveOverlayVisibility(
    platformMode: PlatformMode,
    location: OverlayUserLocation,
    mode: CapsuleMode,
    hasActiveTask: Boolean,
    showPreference: ShowPreference,
): OverlayVisibilityDecision {
    val outsideMain = location != OverlayUserLocation.MAIN_APP
    val needsAttention = mode is CapsuleMode.WaitingForInput || mode is CapsuleMode.WaitingForAction ||
        mode is CapsuleMode.WaitingForApproval || mode is CapsuleMode.Error
    val attentionInMain = platformMode == PlatformMode.VIRTUAL_DISPLAY && !outsideMain && needsAttention
    return OverlayVisibilityDecision(
        showCapsule = outsideMain && showPreference == ShowPreference.CAPSULE || attentionInMain,
        showBubble = outsideMain,
        showGlow = hasActiveTask && when (platformMode) {
            PlatformMode.ACCESSIBILITY -> outsideMain
            PlatformMode.VIRTUAL_DISPLAY -> location == OverlayUserLocation.VD_VIEWER || attentionInMain
        },
    )
}

/** Whether user touch interaction with the underlying screen should be blocked. */
internal fun shouldLockUserInteraction(
    platformMode: PlatformMode,
    location: OverlayUserLocation,
    mode: CapsuleMode,
): Boolean {
    val userOwnsControl = mode is CapsuleMode.Takeover
    val nonInteractiveState = mode is CapsuleMode.Hidden ||
        mode is CapsuleMode.Done ||
        mode is CapsuleMode.Error
    if (userOwnsControl || nonInteractiveState) return false

    return when (platformMode) {
        PlatformMode.ACCESSIBILITY -> location == OverlayUserLocation.OTHER_APP
        PlatformMode.VIRTUAL_DISPLAY -> location == OverlayUserLocation.VD_VIEWER
    }
}
