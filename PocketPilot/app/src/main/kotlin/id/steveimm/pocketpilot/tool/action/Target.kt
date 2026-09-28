package id.steveimm.pocketpilot.tool.action

/** Targeting method for mobile actions. Parsed from LLM JSON params. Resolved to coordinates by TargetResolver. */
sealed interface Target {
    data class ElementIndex(
        val index: Int,
        val coordinateHint: Coordinate? = null
    ) : Target

    data class Text(
        val text: String,
        val textIndex: Int = 0,
        val coordinateHint: Coordinate? = null
    ) : Target

    data class Coordinate(val x: Int, val y: Int) : Target
}
