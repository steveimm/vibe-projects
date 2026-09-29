package id.steveimm.pocketpilot.ui.overlay.model

import id.steveimm.pocketpilot.protocol.TurnPhase

/** GlowState — semantic status for capsule status dot, edge glow, and bubble. */
enum class GlowState {
    Active,
    Executing,
    Success,
    Error,
    Paused,
}

/** Derive GlowState from CapsuleMode + TurnPhase. */
fun deriveGlowState(mode: CapsuleMode, turnPhase: TurnPhase?): GlowState = when {
    mode is CapsuleMode.Error -> GlowState.Error
    mode is CapsuleMode.Done -> GlowState.Success
    mode is CapsuleMode.TakeoverPending || mode is CapsuleMode.Takeover -> GlowState.Paused
    mode is CapsuleMode.WaitingForInput || mode is CapsuleMode.WaitingForAction ||
        mode is CapsuleMode.WaitingForApproval -> GlowState.Paused
    mode is CapsuleMode.Running && turnPhase == TurnPhase.EXECUTION -> GlowState.Executing
    mode is CapsuleMode.Running -> GlowState.Active
    else -> GlowState.Active
}
