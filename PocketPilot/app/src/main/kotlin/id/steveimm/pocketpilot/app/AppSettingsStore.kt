package id.steveimm.pocketpilot.app

import android.content.Context
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.AppTier
import id.steveimm.pocketpilot.protocol.PlatformMode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import org.json.JSONObject

data class AppSettings(
    val serverBaseUrl: String = "",
    val serverModelId: String = "",
    val debugMode: Boolean = AppSettingsStore.DEFAULT_DEBUG_MODE,
    val perceptionMode: String = AppSettingsStore.DEFAULT_PERCEPTION_MODE,
    val platformMode: PlatformMode = AppSettingsStore.DEFAULT_PLATFORM_MODE,
    val traceEnabled: Boolean = AppSettingsStore.DEFAULT_TRACE_ENABLED,
    val termuxShellEnabled: Boolean = AppSettingsStore.DEFAULT_TERMUX_SHELL_ENABLED,
    val approvalMode: ApprovalMode = AppSettingsStore.DEFAULT_APPROVAL_MODE,
)

class AppSettingsStore(context: Context) {
    companion object {
        private const val PREFS_NAME = "agent_prefs"
        private const val KEY_SERVER_BASE_URL = "server_base_url"
        private const val KEY_SERVER_MODEL_ID = "server_model_id"

        private const val KEY_DEBUG_MODE = "debug_mode"
        private const val KEY_SCREENSHOT_INPUT = "screenshot_input"
        private const val KEY_PERCEPTION_MODE = "perception_mode"
        private const val KEY_PLATFORM_MODE = "platform_mode"
        private const val KEY_USER_APP_OVERRIDES = "user_app_overrides"
        private const val KEY_TRACE_ENABLED = "trace_enabled"
        private const val KEY_TERMUX_SHELL_ENABLED = "termux_shell_enabled"
        private const val KEY_APPROVAL_MODE = "approval_mode"
        private const val KEY_COMPACT_OVERLAYS = "compact_overlays"

        const val DEFAULT_DEBUG_MODE = false
        const val DEFAULT_PERCEPTION_MODE = "accessibility_only"
        val DEFAULT_PLATFORM_MODE = PlatformMode.ACCESSIBILITY
        const val DEFAULT_TRACE_ENABLED = false
        const val DEFAULT_TERMUX_SHELL_ENABLED = true
        val DEFAULT_APPROVAL_MODE = ApprovalMode.SMART
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val _termuxShellEnabled = MutableStateFlow(loadTermuxShellEnabled())
    val termuxShellEnabled: StateFlow<Boolean> = _termuxShellEnabled.asStateFlow()

    fun load(): AppSettings {
        val url = prefs.getString(KEY_SERVER_BASE_URL, null)
            ?: prefs.getString("other_base_url", "").orEmpty()
        val legacyModel = prefs.getString("model", "").orEmpty()
        val modelId = prefs.getString(KEY_SERVER_MODEL_ID, null)
            ?: if (legacyModel.startsWith("other:")) legacyModel.removePrefix("other:")
            else prefs.getString("other_model_id", "").orEmpty()
        return AppSettings(
            serverBaseUrl = id.steveimm.pocketpilot.llm.ServerBaseUrlValidator.validate(url).getOrDefault(""),
            serverModelId = modelId,
            debugMode = prefs.getBoolean(KEY_DEBUG_MODE, DEFAULT_DEBUG_MODE),
            perceptionMode = prefs.getString(KEY_PERCEPTION_MODE, null)
                ?: if (prefs.getBoolean(KEY_SCREENSHOT_INPUT, false)) "hybrid" else DEFAULT_PERCEPTION_MODE,
            platformMode = readEnum(KEY_PLATFORM_MODE, DEFAULT_PLATFORM_MODE),
            traceEnabled = prefs.getBoolean(KEY_TRACE_ENABLED, DEFAULT_TRACE_ENABLED),
            termuxShellEnabled = loadTermuxShellEnabled(),
            approvalMode = readEnum(KEY_APPROVAL_MODE, DEFAULT_APPROVAL_MODE)
                .takeUnless { it == ApprovalMode.ALWAYS_ASK } ?: DEFAULT_APPROVAL_MODE,
        )
    }

    fun saveServer(baseUrl: String, modelId: String) {
        prefs.edit().putString(KEY_SERVER_BASE_URL, baseUrl).putString(KEY_SERVER_MODEL_ID, modelId).apply()
    }

    private inline fun <reified T : Enum<T>> readEnum(key: String, default: T): T {
        val name = prefs.getString(key, default.name)
        return enumValues<T>().firstOrNull { it.name == name } ?: default
    }

    fun loadTermuxShellEnabled(): Boolean =
        prefs.getBoolean(KEY_TERMUX_SHELL_ENABLED, DEFAULT_TERMUX_SHELL_ENABLED)

    suspend fun setTermuxShellEnabled(value: Boolean) {
        withContext(Dispatchers.IO) {
            prefs.edit().putBoolean(KEY_TERMUX_SHELL_ENABLED, value).apply()
        }
        _termuxShellEnabled.value = value
    }

    fun saveDebugMode(value: Boolean) {
        prefs.edit().putBoolean(KEY_DEBUG_MODE, value).apply()
    }

    fun loadCompactOverlays(): Boolean = prefs.getBoolean(KEY_COMPACT_OVERLAYS, false)

    fun saveCompactOverlays(value: Boolean) {
        prefs.edit().putBoolean(KEY_COMPACT_OVERLAYS, value).apply()
    }

    fun saveTraceEnabled(value: Boolean) {
        prefs.edit().putBoolean(KEY_TRACE_ENABLED, value).apply()
    }

    fun savePerceptionMode(value: String) {
        prefs.edit().putString(KEY_PERCEPTION_MODE, value).apply()
    }

    fun savePlatformMode(value: PlatformMode) {
        prefs.edit().putString(KEY_PLATFORM_MODE, value.name).apply()
    }

    fun saveApprovalMode(value: ApprovalMode) {
        prefs.edit().putString(KEY_APPROVAL_MODE, value.name).apply()
    }

    fun loadUserAppOverrides(): Map<String, AppTier> {
        val raw = prefs.getString(KEY_USER_APP_OVERRIDES, null) ?: return emptyMap()
        return try {
            val obj = JSONObject(raw)
            buildMap {
                for (key in obj.keys()) {
                    val tier = AppTier.fromString(obj.optString(key))
                    if (tier != null) put(key, tier)
                }
            }
        } catch (_: Exception) {
            emptyMap()
        }
    }

    /** Persist user app overrides synchronously via `commit()` on [Dispatchers.IO]. */
    suspend fun saveUserAppOverrides(overrides: Map<String, AppTier>) {
        withContext(Dispatchers.IO) {
            val editor = prefs.edit()
            if (overrides.isEmpty()) {
                editor.remove(KEY_USER_APP_OVERRIDES).commit()
                return@withContext
            }
            val obj = JSONObject()
            for ((pkg, tier) in overrides) obj.put(pkg, tier.name)
            editor.putString(KEY_USER_APP_OVERRIDES, obj.toString()).commit()
        }
    }

}
