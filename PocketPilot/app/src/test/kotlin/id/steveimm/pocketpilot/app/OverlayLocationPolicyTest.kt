package id.steveimm.pocketpilot.app

import android.view.Display
import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleContext
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import org.junit.Test

class OverlayLocationPolicyTest {

    @Test
    fun `resolve user location detects vd viewer`() {
        val location = resolveUserLocation(
            appPackage = "id.steveimm.pocketpilot",
            packageName = "id.steveimm.pocketpilot",
            className = "id.steveimm.pocketpilot.ui.viewer.VirtualDisplayViewerActivity",
        )
        assertThat(location).isEqualTo(OverlayUserLocation.VD_VIEWER)
    }

    @Test
    fun `resolve user location detects main app activity`() {
        val location = resolveUserLocation(
            appPackage = "id.steveimm.pocketpilot",
            packageName = "id.steveimm.pocketpilot",
            className = "id.steveimm.pocketpilot.app.MainActivity",
        )
        assertThat(location).isEqualTo(OverlayUserLocation.MAIN_APP)
    }

    @Test
    fun `resolve user location detects other app`() {
        val location = resolveUserLocation(
            appPackage = "id.steveimm.pocketpilot",
            packageName = "com.google.android.youtube",
            className = "com.google.android.apps.youtube.app.WatchWhileActivity",
        )
        assertThat(location).isEqualTo(OverlayUserLocation.OTHER_APP)
    }

    @Test
    fun `resolve user location detects other app even without Activity suffix`() {
        val location = resolveUserLocation(
            appPackage = "id.steveimm.pocketpilot",
            packageName = "com.android.settings",
            className = "com.android.settings.Settings",
        )
        assertThat(location).isEqualTo(OverlayUserLocation.OTHER_APP)
    }

    @Test
    fun `resolve user location ignores non-activity windows`() {
        val location = resolveUserLocation(
            appPackage = "id.steveimm.pocketpilot",
            packageName = "com.google.android.youtube",
            className = "android.widget.FrameLayout",
        )
        assertThat(location).isNull()
    }

    @Test
    fun `resolve user location ignores input method windows`() {
        val location = resolveUserLocation(
            appPackage = "id.steveimm.pocketpilot",
            packageName = "com.google.android.inputmethod.latin",
            className = "com.google.android.inputmethod.latin.LatinIME",
        )
        assertThat(location).isNull()
    }

    @Test
    fun `resolve user location ignores androidx library windows`() {
        val location = resolveUserLocation(
            appPackage = "id.steveimm.pocketpilot",
            packageName = "id.steveimm.pocketpilot",
            className = "androidx.compose.ui.platform.ComposeView",
        )
        assertThat(location).isNull()
    }

    @Test
    fun `own obfuscated overlay window does not hide controls by reporting main app`() {
        assertThat(resolveUserLocation(
            appPackage = "id.steveimm.pocketpilot",
            packageName = "id.steveimm.pocketpilot",
            className = "v1.k0",
        )).isNull()
    }

    @Test
    fun `resolve user location ignores non-default display windows`() {
        val location = resolveUserLocation(
            appPackage = "id.steveimm.pocketpilot",
            packageName = "com.google.android.youtube",
            className = "com.google.android.apps.youtube.app.watchwhile.MainActivity",
            displayId = 85,
        )
        assertThat(location).isNull()
    }

    @Test
    fun `resolve user location accepts default display windows`() {
        val location = resolveUserLocation(
            appPackage = "id.steveimm.pocketpilot",
            packageName = "com.google.android.youtube",
            className = "com.google.android.apps.youtube.app.watchwhile.MainActivity",
            displayId = Display.DEFAULT_DISPLAY,
        )
        assertThat(location).isEqualTo(OverlayUserLocation.OTHER_APP)
    }

    @Test
    fun `resolve capsule context maps vd viewer to screen viewing`() {
        val ctx = resolveCapsuleContext(PlatformMode.VIRTUAL_DISPLAY, OverlayUserLocation.VD_VIEWER)
        assertThat(ctx).isEqualTo(CapsuleContext.SCREEN_VIEWING)
    }

    @Test
    fun `resolve capsule context maps vd other app to background`() {
        val ctx = resolveCapsuleContext(PlatformMode.VIRTUAL_DISPLAY, OverlayUserLocation.OTHER_APP)
        assertThat(ctx).isEqualTo(CapsuleContext.BACKGROUND)
    }

    @Test
    fun `bubble remains visible alongside expanded controls`() {
        val cases = listOf(
            deriveOverlayVisibility(
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                location = OverlayUserLocation.OTHER_APP,
                mode = CapsuleMode.Running("thinking"),
                hasActiveTask = true,
                showPreference = ShowPreference.CAPSULE,
            ),
            deriveOverlayVisibility(
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                location = OverlayUserLocation.OTHER_APP,
                mode = CapsuleMode.Running("thinking"),
                hasActiveTask = true,
                showPreference = ShowPreference.BUBBLE,
            ),
            deriveOverlayVisibility(
                platformMode = PlatformMode.ACCESSIBILITY,
                location = OverlayUserLocation.OTHER_APP,
                mode = CapsuleMode.Running("thinking"),
                hasActiveTask = true,
                showPreference = ShowPreference.BUBBLE,
            ),
        )

        cases.forEach { decision ->
            assertThat(decision.showBubble).isTrue()
        }
    }

    @Test
    fun `derive visibility hides all overlays in main app`() {
        val a11y = deriveOverlayVisibility(
            platformMode = PlatformMode.ACCESSIBILITY,
            location = OverlayUserLocation.MAIN_APP,
            mode = CapsuleMode.Running("thinking"),
            hasActiveTask = true,
            showPreference = ShowPreference.CAPSULE,
        )
        val vd = deriveOverlayVisibility(
            platformMode = PlatformMode.VIRTUAL_DISPLAY,
            location = OverlayUserLocation.MAIN_APP,
            mode = CapsuleMode.Running("thinking"),
            hasActiveTask = true,
            showPreference = ShowPreference.CAPSULE,
        )

        assertThat(a11y.showCapsule).isFalse()
        assertThat(a11y.showBubble).isFalse()
        assertThat(a11y.showGlow).isFalse()
        assertThat(vd.showCapsule).isFalse()
        assertThat(vd.showBubble).isFalse()
        assertThat(vd.showGlow).isFalse()
    }

    @Test
    fun `derive visibility shows capsule in vd main app for approval and input modes`() {
        val modes = listOf(
            CapsuleMode.WaitingForApproval(
                callId = "1",
                description = "open Settings",
                appLabel = "Settings",
                packageName = "com.android.settings",
                reason = "test"
            ),
            CapsuleMode.WaitingForInput(question = "q", callId = "1"),
            CapsuleMode.WaitingForAction(instruction = "do", callId = "1"),
            CapsuleMode.Error("error"),
        )
        modes.forEach { mode ->
            val decision = deriveOverlayVisibility(
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                location = OverlayUserLocation.MAIN_APP,
                mode = mode,
                hasActiveTask = mode !is CapsuleMode.Error,
                showPreference = ShowPreference.CAPSULE,
            )
            assertThat(decision.showCapsule).isTrue()
        }
    }

    @Test
    fun `derive visibility shows capsule in vd viewer for approval mode`() {
        val decision = deriveOverlayVisibility(
            platformMode = PlatformMode.VIRTUAL_DISPLAY,
            location = OverlayUserLocation.VD_VIEWER,
            mode = CapsuleMode.WaitingForApproval(
                callId = "1",
                description = "open Settings",
                appLabel = "Settings",
                packageName = "com.android.settings",
                reason = "test"
            ),
            hasActiveTask = true,
            showPreference = ShowPreference.CAPSULE,
        )
        assertThat(decision.showCapsule).isTrue()
    }

    @Test
    fun `derive visibility allows a minimized bubble in accessibility mode`() {
        val decision = deriveOverlayVisibility(
            platformMode = PlatformMode.ACCESSIBILITY,
            location = OverlayUserLocation.OTHER_APP,
            mode = CapsuleMode.Running("thinking"),
            hasActiveTask = true,
            showPreference = ShowPreference.BUBBLE,
        )

        assertThat(decision.showBubble).isTrue()
        assertThat(decision.showCapsule).isFalse()
    }

    @Test
    fun `accessibility prompts can be minimized after opening`() {
        val modes = listOf(
            CapsuleMode.WaitingForInput(question = "q", callId = "1"),
            CapsuleMode.WaitingForAction(instruction = "do", callId = "1"),
            CapsuleMode.Error("error"),
        )
        modes.forEach { mode ->
            val decision = deriveOverlayVisibility(
                platformMode = PlatformMode.ACCESSIBILITY,
                location = OverlayUserLocation.OTHER_APP,
                mode = mode,
                hasActiveTask = mode !is CapsuleMode.Error,
                showPreference = ShowPreference.BUBBLE,
            )
            assertThat(decision.showCapsule).isFalse()
            assertThat(decision.showBubble).isTrue()
        }
    }

    @Test
    fun `virtual display prompts can be minimized after opening`() {
        val modes = listOf(
            CapsuleMode.WaitingForInput(question = "q", callId = "1"),
            CapsuleMode.WaitingForAction(instruction = "do", callId = "1"),
            CapsuleMode.Error("error"),
        )
        modes.forEach { mode ->
            val decision = deriveOverlayVisibility(
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                location = OverlayUserLocation.OTHER_APP,
                mode = mode,
                hasActiveTask = mode !is CapsuleMode.Error,
                showPreference = ShowPreference.BUBBLE,
            )
            assertThat(decision.showCapsule).isFalse()
            assertThat(decision.showBubble).isTrue()
        }
    }

    @Test
    fun `derive visibility shows glow in vd when active and viewer is visible`() {
        val decision = deriveOverlayVisibility(
            platformMode = PlatformMode.VIRTUAL_DISPLAY,
            location = OverlayUserLocation.VD_VIEWER,
            mode = CapsuleMode.Running("thinking"),
            hasActiveTask = true,
            showPreference = ShowPreference.BUBBLE,
        )

        assertThat(decision.showGlow).isTrue()
    }

    @Test
    fun `derive visibility hides glow in vd when task is inactive`() {
        val decision = deriveOverlayVisibility(
            platformMode = PlatformMode.VIRTUAL_DISPLAY,
            location = OverlayUserLocation.OTHER_APP,
            mode = CapsuleMode.Done("done"),
            hasActiveTask = false,
            showPreference = ShowPreference.BUBBLE,
        )

        assertThat(decision.showGlow).isFalse()
    }

    @Test
    fun `derive visibility hides glow in vd background even when task is active`() {
        val decision = deriveOverlayVisibility(
            platformMode = PlatformMode.VIRTUAL_DISPLAY,
            location = OverlayUserLocation.OTHER_APP,
            mode = CapsuleMode.Running("thinking"),
            hasActiveTask = true,
            showPreference = ShowPreference.BUBBLE,
        )

        assertThat(decision.showGlow).isFalse()
    }

    @Test
    fun `completed overlays keep the bubble without an active control glow`() {
        val doneDecision = deriveOverlayVisibility(
            platformMode = PlatformMode.ACCESSIBILITY,
            location = OverlayUserLocation.OTHER_APP,
            mode = CapsuleMode.Done("done"),
            hasActiveTask = false,
            showPreference = ShowPreference.CAPSULE,
        )
        val errorDecision = deriveOverlayVisibility(
            platformMode = PlatformMode.ACCESSIBILITY,
            location = OverlayUserLocation.OTHER_APP,
            mode = CapsuleMode.Error("error"),
            hasActiveTask = false,
            showPreference = ShowPreference.CAPSULE,
        )

        assertThat(doneDecision.showGlow).isFalse()
        assertThat(doneDecision.showBubble).isTrue()
        assertThat(errorDecision.showGlow).isFalse()
        assertThat(errorDecision.showBubble).isTrue()
    }

    @Test
    fun `should lock interaction in a11y running other app`() {
        val lock = shouldLockUserInteraction(
            platformMode = PlatformMode.ACCESSIBILITY,
            location = OverlayUserLocation.OTHER_APP,
            mode = CapsuleMode.Running("thinking"),
        )
        assertThat(lock).isTrue()
    }

    @Test
    fun `should unlock interaction in a11y takeover`() {
        val lock = shouldLockUserInteraction(
            platformMode = PlatformMode.ACCESSIBILITY,
            location = OverlayUserLocation.OTHER_APP,
            mode = CapsuleMode.Takeover("paused"),
        )
        assertThat(lock).isFalse()
    }

    @Test
    fun `should lock interaction in vd viewer running and unlock in takeover`() {
        val locked = shouldLockUserInteraction(
            platformMode = PlatformMode.VIRTUAL_DISPLAY,
            location = OverlayUserLocation.VD_VIEWER,
            mode = CapsuleMode.Running("thinking"),
        )
        val unlocked = shouldLockUserInteraction(
            platformMode = PlatformMode.VIRTUAL_DISPLAY,
            location = OverlayUserLocation.VD_VIEWER,
            mode = CapsuleMode.Takeover("paused"),
        )
        assertThat(locked).isTrue()
        assertThat(unlocked).isFalse()
    }

    @Test
    fun `onMainAppHidden flips MAIN_APP to OTHER_APP`() {
        // Catches the race where the new foreground app's window-state event arrived
        // before MainActivity.onStop fired and was dropped by the isMainAppResumed guard.
        assertThat(resolveLocationOnMainAppHidden(OverlayUserLocation.MAIN_APP))
            .isEqualTo(OverlayUserLocation.OTHER_APP)
    }

    @Test
    fun `onMainAppHidden preserves VD_VIEWER`() {
        // Regression guard: VirtualDisplayViewerActivity.onStart calls onViewerOpened() BEFORE MainActivity.onStop. Clobbering VD_VIEWER →
        // OTHER_APP would lose the edge glow on the first viewer entry until a second user action re-triggered onViewerOpened.
        assertThat(resolveLocationOnMainAppHidden(OverlayUserLocation.VD_VIEWER))
            .isEqualTo(OverlayUserLocation.VD_VIEWER)
    }

    @Test
    fun `onMainAppHidden leaves OTHER_APP unchanged`() {
        assertThat(resolveLocationOnMainAppHidden(OverlayUserLocation.OTHER_APP))
            .isEqualTo(OverlayUserLocation.OTHER_APP)
    }

    @Test
    fun `viewer auto-finish fires when VD viewer goes idle (Hidden, no task)`() {
        assertThat(
            shouldFinishViewerOnIdle(
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                location = OverlayUserLocation.VD_VIEWER,
                mode = CapsuleMode.Hidden,
                hasActiveTask = false,
            )
        ).isTrue()
    }

    @Test
    fun `viewer auto-finish does NOT fire on Done (capsule still showing success)`() {
        assertThat(
            shouldFinishViewerOnIdle(
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                location = OverlayUserLocation.VD_VIEWER,
                mode = CapsuleMode.Done("done"),
                hasActiveTask = false,
            )
        ).isFalse()
    }

    @Test
    fun `viewer auto-finish does NOT fire on Error (user must dismiss)`() {
        assertThat(
            shouldFinishViewerOnIdle(
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                location = OverlayUserLocation.VD_VIEWER,
                mode = CapsuleMode.Error("oops"),
                hasActiveTask = false,
            )
        ).isFalse()
    }

    @Test
    fun `viewer auto-finish does NOT fire while a task is active`() {
        // Defensive: hasActiveTask=true with mode=Hidden shouldn't normally happen, but
        // guard so a transient state doesn't yank the viewer out from under the agent.
        assertThat(
            shouldFinishViewerOnIdle(
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                location = OverlayUserLocation.VD_VIEWER,
                mode = CapsuleMode.Hidden,
                hasActiveTask = true,
            )
        ).isFalse()
    }

    @Test
    fun `viewer auto-finish does NOT fire when user is in MAIN_APP`() {
        assertThat(
            shouldFinishViewerOnIdle(
                platformMode = PlatformMode.VIRTUAL_DISPLAY,
                location = OverlayUserLocation.MAIN_APP,
                mode = CapsuleMode.Hidden,
                hasActiveTask = false,
            )
        ).isFalse()
    }

    @Test
    fun `viewer auto-finish does NOT fire in accessibility platform mode`() {
        // No VD viewer to finish in A11y mode — guard so the rule never misfires.
        assertThat(
            shouldFinishViewerOnIdle(
                platformMode = PlatformMode.ACCESSIBILITY,
                location = OverlayUserLocation.VD_VIEWER,
                mode = CapsuleMode.Hidden,
                hasActiveTask = false,
            )
        ).isFalse()
    }
}
