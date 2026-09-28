package id.steveimm.pocketpilot.agent

import org.json.JSONObject

/** Normalized representation of which UI element a mobile_action targets. */
data class ActionTarget(
    val text: String,
    val textIndex: Int,
    val bounds: Bounds?,
    val point: Point?,
    val elementIndex: Int?,
) {
    data class Bounds(val x1: Int, val y1: Int, val x2: Int, val y2: Int)
    data class Point(val x: Int, val y: Int)
}

/** Decode the UI-element targeting fields from a mobile_action's JSON arguments. */
fun decodeActionTarget(args: JSONObject, action: String = ""): ActionTarget {
    val (text, textIndex) = when {
        action == "type" && args.has("input_text") ->
            args.optString("text", "").trim() to
                    args.optInt("text_index", args.optInt("target_text_index", 0))
        action == "type" ->
            args.optString("target_text", "").trim() to
                    args.optInt("target_text_index", args.optInt("text_index", 0))
        else ->
            args.optString("text", "").trim() to args.optInt("text_index", 0)
    }

    val bounds = if (args.has("x1") && args.has("y1") && args.has("x2") && args.has("y2")) {
        ActionTarget.Bounds(
            args.optInt("x1", -1), args.optInt("y1", -1),
            args.optInt("x2", -1), args.optInt("y2", -1),
        )
    } else null

    val point = if (args.has("x") && args.has("y")) {
        ActionTarget.Point(args.optInt("x", -1), args.optInt("y", -1))
    } else null

    val elementIndex = if (args.has("element_index")) {
        args.optInt("element_index", -1).takeIf { it >= 0 }
    } else null

    return ActionTarget(text, textIndex, bounds, point, elementIndex)
}
