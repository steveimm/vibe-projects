package id.steveimm.pocketpilot.agent

object ActionDescriptionFormatter {
    fun format(call: ToolCallRequest): String = with(call.arguments) {
        when (call.name) {
            "tap", "long_press" -> "${call.name.replace('_', ' ')} (${optInt("x")}, ${optInt("y")})"
            "swipe" -> "Swipe (${optInt("start_x")}, ${optInt("start_y")}) to (${optInt("end_x")}, ${optInt("end_y")})"
            "type_text" -> "Enter \"${optString("text").take(40)}\""
            "open_app" -> "Open ${optString("app_name")}"
            "system_button" -> "Press ${optString("button")}"
            "read_screen" -> "Read screen${optLong("delay_ms", 0).takeIf { it > 0 }?.let { " after $it ms" }.orEmpty()}"
            else -> call.name.replace('_', ' ')
        }
    }
}
