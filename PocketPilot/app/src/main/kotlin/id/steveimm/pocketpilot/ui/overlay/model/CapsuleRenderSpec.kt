package id.steveimm.pocketpilot.ui.overlay.model

import id.steveimm.pocketpilot.protocol.PlatformMode

/** CapsuleRenderSpec — pure rendering specification derived from CapsuleMode. */
data class CapsuleRenderSpec(
    val dot: DotSpec?,
    val thought: ThoughtSpec,
    val expandedBody: String?,
    val buttons: ButtonsSpec,
    val input: InputSpec?,
) {
    /** Status dot configuration. null = dot hidden. */
    data class DotSpec(val status: GlowState, val pulsing: Boolean)

    /** Header status text. */
    data class ThoughtSpec(val text: String, val dimmed: Boolean = false)

    /** A single button in the control bar. The Compose layer chooses the icon. */
    data class ButtonSpec(val text: String, val enabled: Boolean = true)

    /** Control-bar button configuration. null fields = button hidden. */
    data class ButtonsSpec(
        val primary: ButtonSpec?,
        val secondary: ButtonSpec? = null,
        val stop: ButtonSpec?,
    )

    /** Input-bar specification. null = input bar hidden. */
    data class InputSpec(
        val hint: String,
        val submitLabel: String,
    )

    companion object {
        /** Derive the rendering state from the current mode. */
        fun from(
            mode: CapsuleMode,
            isStopPending: Boolean = false,
        ): CapsuleRenderSpec =
            when (mode) {
                is CapsuleMode.Running -> CapsuleRenderSpec(
                    dot = DotSpec(GlowState.Active, pulsing = true),
                    thought = ThoughtSpec(if (mode.thought.isBlank()) "Thinking" else ""),
                    expandedBody = mode.thought.takeIf { it.isNotBlank() },
                    buttons = ButtonsSpec(
                        primary = ButtonSpec("Takeover", enabled = !isStopPending),
                        stop = stopButtonSpec(isStopPending),
                    ),
                    input = InputSpec("Add a note…", "Add note"),
                )

                is CapsuleMode.TakeoverPending -> CapsuleRenderSpec(
                    dot = DotSpec(GlowState.Paused, pulsing = false),
                    thought = ThoughtSpec("Handing over..."),
                    expandedBody = mode.lastThought.takeIf { it.isNotBlank() },
                    buttons = ButtonsSpec(
                        primary = ButtonSpec("Handing over", enabled = false),
                        stop = stopButtonSpec(isStopPending),
                    ),
                    input = InputSpec("Add a note…", "Add note"),
                )

                is CapsuleMode.Takeover -> CapsuleRenderSpec(
                    dot = DotSpec(GlowState.Paused, pulsing = false),
                    thought = ThoughtSpec(
                        "Paused",
                        dimmed = true,
                    ),
                    expandedBody = mode.lastThought.takeIf { it.isNotBlank() },
                    buttons = ButtonsSpec(
                        primary = ButtonSpec("Resume", enabled = !isStopPending),
                        stop = stopButtonSpec(isStopPending),
                    ),
                    input = InputSpec("Add a note…", "Add note"),
                )

                is CapsuleMode.WaitingForInput -> CapsuleRenderSpec(
                    dot = null,
                    thought = ThoughtSpec("Awaiting response"),
                    expandedBody = mode.question,
                    buttons = ButtonsSpec(
                        primary = null,
                        stop = stopButtonSpec(isStopPending),
                    ),
                    input = InputSpec(
                        hint = "Type your response...",
                        submitLabel = "Send",
                    ),
                )

                is CapsuleMode.WaitingForAction -> CapsuleRenderSpec(
                    dot = null,
                    thought = ThoughtSpec("Action needed"),
                    expandedBody = mode.instruction,
                    buttons = ButtonsSpec(
                        primary = ButtonSpec("Done", enabled = !isStopPending),
                        stop = stopButtonSpec(isStopPending),
                    ),
                    input = null,
                )

                is CapsuleMode.WaitingForApproval -> CapsuleRenderSpec(
                    dot = DotSpec(GlowState.Paused, pulsing = false),
                    thought = ThoughtSpec("App access"),
                    expandedBody = "Allow PocketPilot to operate ${mode.appLabel}?",
                    buttons = ButtonsSpec(
                        primary = ButtonSpec("Always"),
                        secondary = ButtonSpec("Session"),
                        stop = ButtonSpec("Reject"),
                    ),
                    input = null,
                )

                is CapsuleMode.Done -> CapsuleRenderSpec(
                    dot = DotSpec(if (mode.stopped) GlowState.Paused else GlowState.Success, pulsing = false),
                    thought = ThoughtSpec(if (mode.stopped) "Stopped" else "Finished"),
                    expandedBody = if (mode.stopped) null else mode.message,
                    buttons = ButtonsSpec(primary = null, stop = null),
                    input = InputSpec("What can I help you with?", "Send"),
                )

                is CapsuleMode.Error -> CapsuleRenderSpec(
                    dot = DotSpec(GlowState.Error, pulsing = false),
                    thought = ThoughtSpec("Error"),
                    expandedBody = mode.message,
                    buttons = ButtonsSpec(primary = null, stop = null),
                    input = InputSpec("New request…", "Send"),
                )

                is CapsuleMode.Hidden -> CapsuleRenderSpec(
                    dot = null,
                    thought = ThoughtSpec(""),
                    expandedBody = null,
                    buttons = ButtonsSpec(primary = null, stop = null),
                    input = InputSpec("What can I help you with?", "Send"),
                )
            }

        private fun stopButtonSpec(isStopPending: Boolean): ButtonSpec =
            if (isStopPending) ButtonSpec("Stopping...", enabled = false)
            else ButtonSpec("Stop")
    }
}

/** NavSpec — navigation button visibility derived from context. */
data class NavSpec(val showClose: Boolean, val showApp: Boolean, val showWatch: Boolean) {
    companion object {
        fun from(context: CapsuleContext, platformMode: PlatformMode, mode: CapsuleMode? = null): NavSpec = NavSpec(
            showClose = context != CapsuleContext.MAIN_APP,
            showApp = context != CapsuleContext.MAIN_APP,
            showWatch = platformMode == PlatformMode.VIRTUAL_DISPLAY && context != CapsuleContext.SCREEN_VIEWING &&
                !(context == CapsuleContext.MAIN_APP && mode is CapsuleMode.Done),
        )
    }
}
