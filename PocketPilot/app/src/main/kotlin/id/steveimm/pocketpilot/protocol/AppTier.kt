package id.steveimm.pocketpilot.protocol

/** App classification tier for security decisions. */
enum class AppTier {
    BLOCKED,
    CAUTIOUS,
    NORMAL;

    companion object {
        fun fromString(value: String): AppTier? =
            entries.firstOrNull { it.name.equals(value, ignoreCase = true) }
    }
}
