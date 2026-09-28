package id.steveimm.pocketpilot.ui.capsule

import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** Capsule-side bridge between the agent runtime and a UI host (e.g. `ChatScreen`). */
data class CapsuleBinding(
    val mode: StateFlow<CapsuleMode>,
    val platformMode: StateFlow<PlatformMode>,
    val isStopPending: StateFlow<Boolean>,
    val previousMode: () -> CapsuleMode?,
    val onStopRequested: () -> Boolean,
    val onApprovalResolved: (String) -> Boolean,
    val onUserResponseSent: (String) -> Boolean,
)

/** No-op binding used when the agent runtime is unbound. */
val InertCapsuleBinding: CapsuleBinding = CapsuleBinding(
    mode = MutableStateFlow(CapsuleMode.Hidden),
    platformMode = MutableStateFlow(PlatformMode.ACCESSIBILITY),
    isStopPending = MutableStateFlow(false),
    previousMode = { null },
    onStopRequested = { true },
    onApprovalResolved = { true },
    onUserResponseSent = { true },
)
