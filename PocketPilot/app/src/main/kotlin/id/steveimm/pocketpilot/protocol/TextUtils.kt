package id.steveimm.pocketpilot.protocol

/** Compact a thought string for surfaces that explicitly opt into a single-line preview (capsule reduced-motion fallback, error/status
 * banners). */
fun compactThought(raw: String): String {
    val trimmed = raw.trim()
    return if (trimmed.length > COMPACT_THOUGHT_MAX) trimmed.take(COMPACT_THOUGHT_MAX) + "..." else trimmed
}

private const val COMPACT_THOUGHT_MAX = 80
