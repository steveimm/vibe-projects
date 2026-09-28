package id.steveimm.pocketpilot.app

import android.content.Context
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.AppTier
import id.steveimm.pocketpilot.protocol.LLMBackendType
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.ui.settings.AVAILABLE_LOCAL_MODELS
import id.steveimm.pocketpilot.ui.settings.LocalModelOption
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

data class AppSettings(
    val selectedModel: String = AppSettingsStore.DEFAULT_MODEL,
    val debugMode: Boolean = AppSettingsStore.DEFAULT_DEBUG_MODE,
    val perceptionMode: String = AppSettingsStore.DEFAULT_PERCEPTION_MODE,
    val llmBackend: LLMBackendType = AppSettingsStore.DEFAULT_LLM_BACKEND,
    val localModel: LocalModelOption = AppSettingsStore.DEFAULT_LOCAL_MODEL,
    val platformMode: PlatformMode = AppSettingsStore.DEFAULT_PLATFORM_MODE,
    val traceEnabled: Boolean = AppSettingsStore.DEFAULT_TRACE_ENABLED,
    val browserScriptEnabled: Boolean = AppSettingsStore.DEFAULT_BROWSER_SCRIPT_ENABLED,
    val termuxShellEnabled: Boolean = AppSettingsStore.DEFAULT_TERMUX_SHELL_ENABLED,
    val openaiBaseUrl: String = "",
    val otherBaseUrl: String = "",
    val otherModelId: String = "",
    val approvalMode: ApprovalMode = AppSettingsStore.DEFAULT_APPROVAL_MODE,
)

class AppSettingsStore(context: Context) {
    companion object {
        private const val PREFS_NAME = "agent_prefs"

        private const val KEY_MODEL = "model"
        private const val KEY_DEBUG_MODE = "debug_mode"
        private const val KEY_SCREENSHOT_INPUT = "screenshot_input"
        private const val KEY_PERCEPTION_MODE = "perception_mode"
        private const val KEY_LLM_BACKEND = "llm_backend"
        private const val KEY_LOCAL_MODEL_ID = "local_model_id"
        private const val KEY_PLATFORM_MODE = "platform_mode"
        private const val KEY_USER_APP_OVERRIDES = "user_app_overrides"
        private const val KEY_TRACE_ENABLED = "trace_enabled"
        private const val KEY_BROWSER_SCRIPT_ENABLED = "browser_script_enabled"
        private const val KEY_TERMUX_SHELL_ENABLED = "termux_shell_enabled"
        private const val KEY_OPENAI_BASE_URL = "openai_base_url"
        private const val KEY_OTHER_BASE_URL = "other_base_url"
        private const val KEY_OTHER_MODEL_ID = "other_model_id"
        private const val KEY_DISABLED_AGENT_SKILLS = "disabled_agent_skills"
        private const val KEY_APPROVAL_MODE = "approval_mode"
        private const val KEY_COMPACT_OVERLAYS = "compact_overlays"

        const val DEFAULT_MODEL = "glm-5"
        const val DEFAULT_DEBUG_MODE = false
        const val DEFAULT_PERCEPTION_MODE = "accessibility_only"
        val DEFAULT_LLM_BACKEND = LLMBackendType.OPENAI
        val DEFAULT_LOCAL_MODEL: LocalModelOption = AVAILABLE_LOCAL_MODELS.first()
        val DEFAULT_PLATFORM_MODE = PlatformMode.ACCESSIBILITY
        const val DEFAULT_TRACE_ENABLED = false
        const val DEFAULT_BROWSER_SCRIPT_ENABLED = false
        const val DEFAULT_TERMUX_SHELL_ENABLED = true
        val DEFAULT_APPROVAL_MODE = ApprovalMode.SMART
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val _termuxShellEnabled = MutableStateFlow(loadTermuxShellEnabled())
    val termuxShellEnabled: StateFlow<Boolean> = _termuxShellEnabled.asStateFlow()

    private val _browserScriptEnabled = MutableStateFlow(loadBrowserScriptEnabled())
    val browserScriptEnabled: StateFlow<Boolean> = _browserScriptEnabled.asStateFlow()

    private val _disabledAgentSkills = MutableStateFlow(loadDisabledAgentSkills())
    val disabledAgentSkills: StateFlow<Set<String>> = _disabledAgentSkills.asStateFlow()

    // Serializes setSkillDisabled so concurrent toggles from the UI cannot lose entries
    // via the read-modify-write between _disabledAgentSkills.value and the prefs commit.
    private val disabledSkillsMutex = Mutex()

    fun load(): AppSettings {
        val localModelId = prefs.getString(KEY_LOCAL_MODEL_ID, null)
        return AppSettings(
            selectedModel = prefs.getString(KEY_MODEL, DEFAULT_MODEL) ?: DEFAULT_MODEL,
            debugMode = prefs.getBoolean(KEY_DEBUG_MODE, DEFAULT_DEBUG_MODE),
            perceptionMode = prefs.getString(KEY_PERCEPTION_MODE, null)
                ?: if (prefs.getBoolean(KEY_SCREENSHOT_INPUT, false)) "hybrid" else DEFAULT_PERCEPTION_MODE,
            llmBackend = readEnum(KEY_LLM_BACKEND, DEFAULT_LLM_BACKEND),
            localModel = AVAILABLE_LOCAL_MODELS.find { it.id == localModelId } ?: DEFAULT_LOCAL_MODEL,
            platformMode = readEnum(KEY_PLATFORM_MODE, DEFAULT_PLATFORM_MODE),
            traceEnabled = prefs.getBoolean(KEY_TRACE_ENABLED, DEFAULT_TRACE_ENABLED),
            browserScriptEnabled = loadBrowserScriptEnabled(),
            termuxShellEnabled = loadTermuxShellEnabled(),
            openaiBaseUrl = prefs.getString(KEY_OPENAI_BASE_URL, "").orEmpty(),
            otherBaseUrl = prefs.getString(KEY_OTHER_BASE_URL, "").orEmpty(),
            otherModelId = prefs.getString(KEY_OTHER_MODEL_ID, "").orEmpty(),
            approvalMode = readEnum(KEY_APPROVAL_MODE, DEFAULT_APPROVAL_MODE)
                .takeUnless { it == ApprovalMode.ALWAYS_ASK } ?: DEFAULT_APPROVAL_MODE,
        )
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

    fun loadBrowserScriptEnabled(): Boolean =
        prefs.getBoolean(KEY_BROWSER_SCRIPT_ENABLED, DEFAULT_BROWSER_SCRIPT_ENABLED)

    suspend fun setBrowserScriptEnabled(value: Boolean) {
        withContext(Dispatchers.IO) {
            prefs.edit().putBoolean(KEY_BROWSER_SCRIPT_ENABLED, value).apply()
        }
        _browserScriptEnabled.value = value
    }

    fun saveModel(value: String) {
        prefs.edit().putString(KEY_MODEL, value).apply()
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

    fun saveBrowserScriptEnabled(value: Boolean) {
        prefs.edit().putBoolean(KEY_BROWSER_SCRIPT_ENABLED, value).apply()
        _browserScriptEnabled.value = value
    }

    fun savePerceptionMode(value: String) {
        prefs.edit().putString(KEY_PERCEPTION_MODE, value).apply()
    }

    fun saveOpenaiBaseUrl(value: String) = saveOptionalString(KEY_OPENAI_BASE_URL, value)

    fun saveOtherBaseUrl(value: String) = saveOptionalString(KEY_OTHER_BASE_URL, value)

    fun saveOtherModelId(value: String) = saveOptionalString(KEY_OTHER_MODEL_ID, value)

    private fun saveOptionalString(key: String, value: String) {
        val editor = prefs.edit()
        if (value.isBlank()) editor.remove(key) else editor.putString(key, value)
        editor.apply()
    }

    fun saveBackend(value: LLMBackendType) {
        prefs.edit().putString(KEY_LLM_BACKEND, value.name).apply()
    }

    fun savePlatformMode(value: PlatformMode) {
        prefs.edit().putString(KEY_PLATFORM_MODE, value.name).apply()
    }

    fun saveApprovalMode(value: ApprovalMode) {
        prefs.edit().putString(KEY_APPROVAL_MODE, value.name).apply()
    }

    fun saveLocalModel(model: LocalModelOption) {
        prefs.edit().putString(KEY_LOCAL_MODEL_ID, model.id).apply()
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

    fun loadDisabledAgentSkills(): Set<String> {
        val raw = prefs.getString(KEY_DISABLED_AGENT_SKILLS, null) ?: return emptySet()
        return try {
            val arr = JSONArray(raw)
            buildSet {
                for (i in 0 until arr.length()) {
                    val name = arr.optString(i)
                    if (name.isNotEmpty()) add(name)
                }
            }
        } catch (_: Exception) {
            emptySet()
        }
    }

    suspend fun setSkillDisabled(name: String, disabled: Boolean) = disabledSkillsMutex.withLock {
        val current = _disabledAgentSkills.value
        val next = if (disabled) current + name else current - name
        if (next == current) return@withLock
        withContext(Dispatchers.IO) {
            val editor = prefs.edit()
            if (next.isEmpty()) {
                editor.remove(KEY_DISABLED_AGENT_SKILLS).apply()
            } else {
                val arr = JSONArray()
                next.forEach { arr.put(it) }
                editor.putString(KEY_DISABLED_AGENT_SKILLS, arr.toString()).apply()
            }
        }
        _disabledAgentSkills.value = next
    }
}
