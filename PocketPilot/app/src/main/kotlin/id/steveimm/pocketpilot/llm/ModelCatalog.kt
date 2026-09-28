package id.steveimm.pocketpilot.llm

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** Which OpenAI-compatible API shape this model uses. */
enum class ApiType {
    /** OpenAI Responses API (native function calling, streaming). */
    RESPONSE,

    /** OpenAI Chat Completions API (widely compatible with third-party providers). */
    CHAT
}

/** One model entry from `llm_models.json`. */
data class ModelEntry(
        val name: String,
        val displayName: String,
        val provider: LLMProvider,
        val api: ApiType,
        val modelId: String,
        val contextWindow: Int,
        val baseUrl: String? = null,
        val apiKeyEnv: String? = null,
        val supportsVision: Boolean = true,
        val created: Long = 0L,
) {
    /** Effective API key env var (entry override or provider default). */
    val effectiveApiKeyEnv: String
        get() = apiKeyEnv ?: provider.defaultApiKeyEnv

    /** Effective base URL (entry override or provider default). */
    val effectiveBaseUrl: String?
        get() = baseUrl ?: provider.defaultBaseUrl
}

/** Loads, caches, and resolves model entries from `llm_models.json`. */
class ModelCatalog private constructor(private val entries: Map<String, ModelEntry>) {
    /** Resolve a model by name (the JSON key). */
    fun resolve(name: String): ModelEntry =
            entries[name]
                    ?: throw IllegalArgumentException(
                            "Unknown model '$name'. Available: ${entries.keys.sorted()}"
                    )

    /** Resolve a model by name, returning null if not found. */
    fun resolveOrNull(name: String): ModelEntry? = entries[name]

    /** All entries, in insertion order. */
    fun all(): List<ModelEntry> = entries.values.toList()

    /** All model names (JSON keys). */
    fun names(): Set<String> = entries.keys

    /** Number of models in the catalog. */
    val size: Int
        get() = entries.size

    /** Check if a model name exists. */
    operator fun contains(name: String): Boolean = name in entries

    /** Models for a given provider, optionally filtered by API type. */
    fun modelsFor(provider: LLMProvider, api: ApiType? = null): List<ModelEntry> =
            entries.values.filter { it.provider == provider && (api == null || it.api == api) }

    /** First (preferred) model for a given provider/API type, or null if none match. */
    fun preferredModelFor(provider: LLMProvider, api: ApiType? = null): ModelEntry? =
            modelsFor(provider, api).firstOrNull()

    /** Default model key for a provider — the first catalog entry whose provider matches. */
    fun defaultModel(provider: LLMProvider): String =
            preferredModelFor(provider)?.name
                    ?: throw IllegalArgumentException(
                            "No catalog entry for provider $provider"
                    )

    /** Return a new catalog with provider-level base URL overrides applied. */
    fun withBaseUrlOverrides(overrides: Map<LLMProvider, String>): ModelCatalog {
        if (overrides.isEmpty()) return this
        val overridden = entries.mapValues { (_, entry) ->
            val override = overrides[entry.provider]
            if (override != null && entry.baseUrl == null) entry.copy(baseUrl = override) else entry
        }
        return ModelCatalog(LinkedHashMap(overridden))
    }

    /** Return a new catalog with [extras] appended. Used by [ModelCatalogRepository] to overlay runtime-synthesized entries (the OTHER
     * `other-custom` row in PR1; discovered entries in PR2) on top of the JSON seed. */
    fun withExtraEntries(extras: List<ModelEntry>): ModelCatalog {
        if (extras.isEmpty()) return this
        val merged = LinkedHashMap(entries)
        for (extra in extras) {
            require(extra.name.isNotBlank()) { "Extra ModelEntry name must not be blank" }
            merged[extra.name] = extra
        }
        return ModelCatalog(merged)
    }

    companion object {
        private val json = Json { ignoreUnknownKeys = true }

        /** Parse from JSON string (read from assets or file). */
        fun fromJson(jsonString: String): ModelCatalog {
            val raw: Map<String, JsonModelEntry> = json.decodeFromString(jsonString)
            require(raw.isNotEmpty()) { "Model catalog JSON must contain at least one model" }

            val entries = LinkedHashMap(raw.mapValues { (name, entry) -> entry.toModelEntry(name) })
            return ModelCatalog(entries)
        }
    }
}

/** Wire format for a single model entry in `llm_models.json`. */
@Serializable
internal data class JsonModelEntry(
        @SerialName("display_name") val displayName: String,
        val provider: String,
        val api: String,
        @SerialName("model_id") val modelId: String,
        @SerialName("base_url") val baseUrl: String? = null,
        @SerialName("api_key_env") val apiKeyEnv: String? = null,
        @SerialName("supports_vision") val supportsVision: Boolean = true,
        @SerialName("context_window") val contextWindow: Int? = null
) {
    fun toModelEntry(name: String): ModelEntry {
        require(name.isNotBlank()) { "Model name must not be blank" }
        require(displayName.isNotBlank()) { "display_name must not be blank for model '$name'" }
        require(modelId.isNotBlank()) { "model_id must not be blank for model '$name'" }

        val resolvedProvider =
                try {
                    LLMProvider.valueOf(provider.uppercase())
                } catch (e: IllegalArgumentException) {
                    throw IllegalArgumentException(
                            "Unknown provider '$provider' for model '$name'. " +
                                    "Valid: ${LLMProvider.entries.map { it.name }}"
                    )
                }
        val resolvedApi =
                when (api.lowercase()) {
                    "response" -> ApiType.RESPONSE
                    "chat" -> ApiType.CHAT
                    else ->
                            throw IllegalArgumentException(
                                    "Unknown api type '$api' for model '$name'. Valid: response, chat"
                            )
                }
        val resolvedContextWindow =
                contextWindow
                        ?: when (resolvedProvider.mode) {
                            AuthMode.Local -> 8_000
                            else -> 128_000
                        }
        require(resolvedContextWindow > 0) {
            "context_window must be > 0 for model '$name' (got $resolvedContextWindow)"
        }
        return ModelEntry(
                name = name,
                displayName = displayName,
                provider = resolvedProvider,
                api = resolvedApi,
                modelId = modelId,
                contextWindow = resolvedContextWindow,
                baseUrl = baseUrl,
                apiKeyEnv = apiKeyEnv,
                supportsVision = supportsVision
        )
    }
}
