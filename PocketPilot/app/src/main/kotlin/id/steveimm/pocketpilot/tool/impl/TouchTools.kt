package id.steveimm.pocketpilot.tool.impl

import id.steveimm.pocketpilot.platform.UIAction
import id.steveimm.pocketpilot.tool.*
import id.steveimm.pocketpilot.tool.handlers.UIActionInvocation
import kotlin.math.abs
import kotlin.math.roundToInt
import org.json.JSONObject

/** One gesture per call, using the same normalized coordinates at every image/display resolution. */
class TouchTool(override val name: String) : ToolSpec {
    init { require(name in setOf("tap", "long_press", "swipe")) }

    override val description: String = when (name) {
        "tap" -> "Tap a visible target in the latest screenshot. x and y use 0–1000: top-left (0,0), bottom-right (1000,1000)."
        "long_press" -> "Hold a visible target. x and y use 0–1000 across the latest screenshot. Default hold is 1000 ms."
        else -> "Swipe from start to end. All coordinates use 0–1000 across the latest screenshot. Swipe upward to scroll down."
    }

    override val parameterSchema = parameterObject(buildMap {
        val axes = if (name == "swipe") listOf("start_x", "start_y", "end_x", "end_y") else listOf("x", "y")
        axes.forEach { put(it, integerParameter("Position from 0 to 1000 across the screenshot", 0, 1000)) }
        if (name != "tap") put("duration_ms", integerParameter("Gesture duration in milliseconds", 100, 3000))
    }, if (name == "swipe") listOf("start_x", "start_y", "end_x", "end_y") else listOf("x", "y"))

    override fun validate(params: JSONObject): ValidationResult = validateToolParameters(params, parameterSchema)

    override fun createInvocation(params: JSONObject): ToolInvocation = object : ToolInvocation {
        override val toolName = name
        override val params = params
        override fun getDescription(): String = "$name $params"

        override suspend fun execute(context: ToolExecutionContext): ToolExecutionResult {
            if (context.isCancelled()) return ToolExecutionResult.Cancelled()
            val image = context.currentSnapshot?.image
                ?: return ToolExecutionResult.Failure("No current screenshot. Use read_screen to capture the screen before a gesture.")
            val display = context.platform.getDisplayInfo()
            if (image.width <= 0 || image.height <= 0 || display.widthPixels <= 0 || display.heightPixels <= 0) {
                return ToolExecutionResult.Failure("Screen dimensions are unavailable. Use read_screen to capture again.")
            }
            if (abs(image.width.toDouble() / image.height - display.widthPixels.toDouble() / display.heightPixels) > 0.02) {
                return ToolExecutionResult.Failure("Display orientation changed since the screenshot. Use read_screen before retrying.")
            }
            fun x(key: String) = (params.getInt(key) / 1000.0 * (display.widthPixels - 1)).roundToInt()
            fun y(key: String) = (params.getInt(key) / 1000.0 * (display.heightPixels - 1)).roundToInt()
            val action = when (name) {
                "tap" -> UIAction.TapAt(x("x"), y("y"))
                "long_press" -> UIAction.LongPressAt(x("x"), y("y"), params.optLong("duration_ms", 1000))
                else -> UIAction.Swipe(x("start_x"), y("start_y"), x("end_x"), y("end_y"), params.optLong("duration_ms", 400))
            }
            return UIActionInvocation(name, params, getDescription(), action).execute(context)
        }
    }
}

class TypeTextTool : ToolSpec {
    override val name = "type_text"
    override val description = "Replace the entire focused text field with text. Tap the field first. Empty text clears it."
    override val parameterSchema = parameterObject(mapOf("text" to JSONObject().put("type", "string")))
    override fun validate(params: JSONObject): ValidationResult = validateToolParameters(params, parameterSchema)
    override fun createInvocation(params: JSONObject): ToolInvocation = UIActionInvocation(
        name, params, "Enter text in focused field", UIAction.SetTextOnFocused(params.getString("text"), clear = true),
        requiresScreenshot = true,
    )
}
