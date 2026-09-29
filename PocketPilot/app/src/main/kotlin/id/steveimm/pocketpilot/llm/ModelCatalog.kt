package id.steveimm.pocketpilot.llm

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ModelEntry(
    val name: String,
    @SerialName("display_name") val displayName: String = name,
    @SerialName("model_id") val modelId: String = name,
    @SerialName("context_window") val contextWindow: Int = DEFAULT_CONTEXT_WINDOW,
    val created: Long = 0L,
) {
    companion object {
        const val DEFAULT_CONTEXT_WINDOW = 128_000
    }
}

class ModelCatalog private constructor(private val entries: Map<String, ModelEntry>) {
    fun resolve(name: String): ModelEntry = entries[name] ?: throw IllegalArgumentException("Select a model served by your server")
    fun resolveOrNull(name: String): ModelEntry? = entries[name]
    fun names(): Set<String> = entries.keys

    companion object {
        fun fromEntries(entries: List<ModelEntry>): ModelCatalog = ModelCatalog(entries.associateBy { it.name })
    }
}
