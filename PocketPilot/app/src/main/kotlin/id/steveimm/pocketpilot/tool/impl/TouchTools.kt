package id.steveimm.pocketpilot.tool.impl

import id.steveimm.pocketpilot.platform.UIAction
import id.steveimm.pocketpilot.tool.*
import id.steveimm.pocketpilot.tool.handlers.UIActionInvocation
import kotlin.math.abs
import kotlin.math.roundToInt
import org.json.JSONArray
import org.json.JSONObject

/** One gesture per call, using the same normalized coordinates at every image/display resolution. */
class TouchTool(override val name: String) : ToolSpec {
    init { require(name in setOf("tap", "long_press", "swipe")) }

    override val description: String = when (name) {
        "tap" -> "Tap a visible target. point is [x, y] with two integers from 0 to 1000 over the full screenshot."
        "long_press" -> "Hold a visible target. point is [x, y] with integers from 0 to 1000. Default hold is 1000 ms."
        else -> "Swipe from start [x, y] to end [x, y]. Use integers from 0 to 1000 over the full screenshot. " +
            "Swipe upward to scroll down. Default duration is 400 ms."
    }

    override val parameterSchema = parameterObject(buildMap {
        val points = if (name == "swipe") listOf("start", "end") else listOf("point")
        points.forEach {
            put(it, JSONObject().put("type", "array").put("description", "[x, y]: top-left [0,0], bottom-right [1000,1000]")
                .put("items", integerParameter("Coordinate", 0, 1000)).put("minItems", 2).put("maxItems", 2))
        }
        if (name != "tap") put("duration_ms", integerParameter("Gesture duration in milliseconds", 100, 3000))
    }, if (name == "swipe") listOf("start", "end") else listOf("point")).apply {
        val example = if (name == "swipe") JSONObject("""{"start":[500,800],"end":[500,300]}""")
            else JSONObject("""{"point":[500,500]}""")
        put("examples", JSONArray().put(example))
    }

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
            fun x(key: String) = (params.getJSONArray(key).getInt(0) / 1000.0 * (display.widthPixels - 1)).roundToInt()
            fun y(key: String) = (params.getJSONArray(key).getInt(1) / 1000.0 * (display.heightPixels - 1)).roundToInt()
            val action = when (name) {
                "tap" -> UIAction.TapAt(x("point"), y("point"))
                "long_press" -> UIAction.LongPressAt(x("point"), y("point"), params.optLong("duration_ms", 1000))
                else -> UIAction.Swipe(x("start"), y("start"), x("end"), y("end"), params.optLong("duration_ms", 400))
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
