package id.steveimm.pocketpilot.tool

/** Canonical tool identifiers used across UI and policy layers. */
sealed class ToolName(
    val raw: String,
    val canonical: String,
    val displayName: String
) {
    val isScreenChanging: Boolean
        get() =
            when (this) {
                Tap, LongPress, Swipe, TypeText, OpenApp, SystemButton -> true
                ReadScreen, AskUser, TermuxShell -> false
                is Unknown -> true
            }

    data object Tap : ToolName("tap", "tap", "Tap")
    data object LongPress : ToolName("long_press", "long_press", "Long press")
    data object Swipe : ToolName("swipe", "swipe", "Swipe")
    data object TypeText : ToolName("type_text", "type_text", "Type text")
    data object OpenApp : ToolName(
        raw = "open_app",
        canonical = "open_app",
        displayName = "Open app"
    )
    data object ReadScreen : ToolName(
        raw = "read_screen",
        canonical = "read_screen",
        displayName = "Read screen"
    )
    data object SystemButton : ToolName(
        raw = "system_button",
        canonical = "system_button",
        displayName = "System button"
    )
    data object AskUser : ToolName(
        raw = "ask_user",
        canonical = "ask_user",
        displayName = "Ask user"
    )
    data object TermuxShell : ToolName(
        raw = "termux_shell",
        canonical = "termux_shell",
        displayName = "Termux shell"
    )
    data class Unknown(private val name: String) : ToolName(
        raw = name,
        canonical = normalizeName(name),
        displayName = formatDisplayName(name)
    )

    companion object {
        fun from(raw: String): ToolName {
            return when (normalizeName(raw)) {
                Tap.canonical -> Tap
                LongPress.canonical -> LongPress
                Swipe.canonical -> Swipe
                TypeText.canonical -> TypeText
                OpenApp.canonical -> OpenApp
                ReadScreen.canonical -> ReadScreen
                SystemButton.canonical -> SystemButton
                AskUser.canonical -> AskUser
                TermuxShell.canonical -> TermuxShell
                else -> Unknown(raw)
            }
        }
    }
}

private fun normalizeName(raw: String): String {
    return raw.trim()
        .lowercase()
        .replace("-", "_")
        .replace("\\s+".toRegex(), "_")
}

private fun formatDisplayName(raw: String): String {
    val trimmed = raw.trim()
    val normalized = trimmed
        .replace("-", " ")
        .replace("_", " ")
        .trim()
    if (normalized.isEmpty()) return "Tool"
    return normalized.replaceFirstChar { it.uppercase() }
}
