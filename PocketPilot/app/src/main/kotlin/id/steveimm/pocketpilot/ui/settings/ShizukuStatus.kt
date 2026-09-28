package id.steveimm.pocketpilot.ui.settings

sealed class ShizukuStatus {
    object Unavailable : ShizukuStatus()
    object NeedsPermission : ShizukuStatus()
    object Ready : ShizukuStatus()
}
