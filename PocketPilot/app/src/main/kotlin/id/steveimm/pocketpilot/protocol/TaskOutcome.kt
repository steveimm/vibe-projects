package id.steveimm.pocketpilot.protocol

/** How execution ended; FINISHED does not assert that the user's goal was verified. */
enum class TaskOutcome {
    FINISHED,
    ERROR,
    USER_STOPPED;

    companion object {
        fun fromStoredName(name: String?): TaskOutcome? = when (name) {
            "GOAL_ACHIEVED", "TASK_IMPOSSIBLE" -> FINISHED
            else -> entries.firstOrNull { it.name == name }
        }
    }
}
