package id.steveimm.pocketpilot.agent.cognition.prompt

import id.steveimm.pocketpilot.BuildConfig
import id.steveimm.pocketpilot.model.ScreenImage
import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.perception.mergedText
import org.json.JSONArray

/** The current screenshot and its context, without a second targeting system. */
data class TurnObservation(val image: ScreenImage?, val screenBlock: String) {
    companion object {
        fun capture(snapshot: ScreenSnapshot, currentPackageName: String? = null): TurnObservation = TurnObservation(
            snapshot.image,
            buildString {
                currentPackageName?.let { appendLine("Foreground app: $it") }
                if (currentPackageName == BuildConfig.APPLICATION_ID) {
                    appendLine("This is PocketPilot, your own interface. Its chat, reasoning and status belong to this conversation.")
                }
                appendLine("Keyboard visible: ${snapshot.keyboardVisible}")
                if (snapshot.image != null) {
                    val controls = snapshot.elements.asSequence()
                        .filter { it.isEnabled && (it.isClickable || it.isEditable) && it.bounds.width > 0 && it.bounds.height > 0 }
                        .map { mergedText(it).filterNot(Char::isISOControl).trim().take(100) }
                        .filter { it.isNotEmpty() }.distinct().take(24).toList()
                    if (controls.isNotEmpty()) appendLine("Visible interactive controls: ${JSONArray(controls)}")
                    append("Current screenshot attached. Touch coordinates: 0–1000 across the full image.")
                } else {
                    append("Screenshot unavailable. Use read_screen to capture again; do not guess touch targets.")
                }
            }.trim(),
        )
    }
}
