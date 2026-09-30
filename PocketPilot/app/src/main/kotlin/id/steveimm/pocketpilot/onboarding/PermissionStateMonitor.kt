package id.steveimm.pocketpilot.onboarding

import android.content.ComponentName
import android.content.Context
import android.os.PowerManager
import android.provider.Settings
import id.steveimm.pocketpilot.app.AgentService

/** Live permission state checks. */
class PermissionStateMonitor(private val context: Context) {

    fun isAccessibilityEnabled(): Boolean {
        val service = ComponentName(context, AgentService::class.java)
        val enabled = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        return enabled.orEmpty().split(':').any { ComponentName.unflattenFromString(it) == service }
    }

    fun isOverlayEnabled(): Boolean = Settings.canDrawOverlays(context)

    fun isBatteryOptimized(): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    /** Data class for post-onboarding repair card. */
    data class PermissionRepairModel(
        val accessibilityMissing: Boolean,
        val overlayMissing: Boolean,
        val batteryMissing: Boolean,
        val accessibilityConnecting: Boolean = false,
    ) {
        val hasAnyIssue: Boolean
            get() = accessibilityMissing || overlayMissing || batteryMissing || accessibilityConnecting

        /** Highest-priority missing permission label. */
        val primaryIssue: String?
            get() = when {
                accessibilityMissing -> "Accessibility service is disabled"
                overlayMissing -> "Overlay permission is revoked"
                batteryMissing -> "Battery optimization re-enabled"
                accessibilityConnecting -> "Accessibility service is connecting"
                else -> null
            }
    }

    /** Derive repair model for post-onboarding state. */
    fun deriveRepairModel(batteryWasDone: Boolean): PermissionRepairModel? =
        deriveRepairModel(
            accessibilityEnabled = isAccessibilityEnabled(),
            overlayEnabled = isOverlayEnabled(),
            batteryIgnoringOptimizations = isBatteryOptimized(),
            batteryWasDone = batteryWasDone,
            accessibilityConnected = AgentService.connected.value,
        )

    companion object {
        /** Pure logic for repair-model derivation. Unit-testable without Android. */
        fun deriveRepairModel(
            accessibilityEnabled: Boolean,
            overlayEnabled: Boolean,
            batteryIgnoringOptimizations: Boolean,
            batteryWasDone: Boolean,
            accessibilityConnected: Boolean = accessibilityEnabled,
        ): PermissionRepairModel? {
            val model = PermissionRepairModel(
                accessibilityMissing = !accessibilityEnabled,
                overlayMissing = !overlayEnabled,
                batteryMissing = batteryWasDone && !batteryIgnoringOptimizations,
                accessibilityConnecting = accessibilityEnabled && !accessibilityConnected,
            )
            return if (model.hasAnyIssue) model else null
        }
    }
}
