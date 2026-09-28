package id.steveimm.pocketpilot.perception

/** Tunables for a11y element filtering and prompt shaping inside [Perceptor]. */
data class PerceptorFilterConfig(
    val maxElements: Int = 500,
    val minElementSizePx: Int = 5,
    val visibilityThreshold: Float = 0.10f,
    val interactiveVisibilityThreshold: Float = 0.01f,
    val filterKeyboard: Boolean = true,
    val clipBounds: Boolean = true,
    val resourceIdOutputDensityThreshold: Float = 0.20f,
    val rowSnapScreenRatio: Float = 0.02f,
    val interactiveKeepRatio: Float = 0.80f,
    val useVisibleToUserFilter: Boolean = true
) {
    companion object {
        val DEFAULT = PerceptorFilterConfig()
    }
}
