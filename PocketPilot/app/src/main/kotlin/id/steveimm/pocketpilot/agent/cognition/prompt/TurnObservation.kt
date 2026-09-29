package id.steveimm.pocketpilot.agent.cognition.prompt

import id.steveimm.pocketpilot.model.ScreenImage
import id.steveimm.pocketpilot.model.ScreenSnapshot

/** The current screenshot and its context, without a second targeting system. */
data class TurnObservation(val image: ScreenImage?, val screenBlock: String) {
    companion object {
        fun capture(snapshot: ScreenSnapshot, currentPackageName: String? = null): TurnObservation = TurnObservation(
            snapshot.image,
            buildString {
                currentPackageName?.let { appendLine("Foreground app: $it") }
                appendLine("Keyboard visible: ${snapshot.keyboardVisible}")
                if (snapshot.image != null) {
                    append("Current screenshot attached. Touch coordinates: 0–1000 across the full image.")
                } else {
                    append("Screenshot unavailable. Use wait to capture again; do not guess touch targets.")
                }
            }.trim(),
        )
    }
}
