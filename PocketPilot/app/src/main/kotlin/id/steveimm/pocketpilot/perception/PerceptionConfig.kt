package id.steveimm.pocketpilot.perception

/** Screenshot quality for the phone's visual observation. */
data class PerceptionConfig(
    val maxDimension: Int = DEFAULT_MAX_DIMENSION,
    val jpegQuality: Int = DEFAULT_JPEG_QUALITY,
) {
    companion object {
        const val DEFAULT_MAX_DIMENSION = 1024
        const val DEFAULT_JPEG_QUALITY = 70
        val DEFAULT = PerceptionConfig()
    }
}

val PerceptionConfig.screenshotMaxDimension: Int get() = maxDimension
val PerceptionConfig.screenshotJpegQuality: Int get() = jpegQuality
