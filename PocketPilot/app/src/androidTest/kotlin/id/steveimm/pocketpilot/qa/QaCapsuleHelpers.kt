package id.steveimm.pocketpilot.qa

import id.steveimm.pocketpilot.protocol.ApprovalDecision
import id.steveimm.pocketpilot.protocol.ApprovalScope
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.ui.capsule.NavAction
import id.steveimm.pocketpilot.ui.capsule.surface.SmartCapsuleSurface
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleContext
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import id.steveimm.pocketpilot.ui.theme.PocketPilotTheme
import androidx.compose.runtime.Composable

@Composable
fun TestCapsule(
    mode: CapsuleMode,
    isStopPending: Boolean = false,
    platformMode: PlatformMode = PlatformMode.ACCESSIBILITY,
    context: CapsuleContext = CapsuleContext.MAIN_APP,
    hasIsland: Boolean = true,
    previousMode: CapsuleMode? = null,
    onSend: (String) -> Unit = {},
    onSupplement: (String) -> Unit = {},
    onTakeover: () -> Unit = {},
    onResume: () -> Unit = {},
    onSupplementAndResume: (String) -> Unit = { text ->
        onSupplement(text)
        onResume()
    },
    onStop: () -> Unit = {},
    onUserResponse: (String, String) -> Unit = { _, _ -> },
    onApprovalResponse: (String, ApprovalDecision, ApprovalScope, String) -> Unit = { _, _, _, _ -> },
    onDismissError: () -> Unit = {},
    onNavigate: (NavAction) -> Unit = {},
) {
    PocketPilotTheme {
        SmartCapsuleSurface(
            mode = mode,
            isStopPending = isStopPending,
            platformMode = platformMode,
            context = context,
            onSend = onSend,
            onSupplement = onSupplement,
            onTakeover = onTakeover,
            onResume = onResume,
            onSupplementAndResume = onSupplementAndResume,
            onStop = onStop,
            onUserResponse = onUserResponse,
            onApprovalResponse = onApprovalResponse,
            onDismissError = onDismissError,
            onNavigate = onNavigate,
            hasIsland = hasIsland,
            previousMode = previousMode,
        )
    }
}
