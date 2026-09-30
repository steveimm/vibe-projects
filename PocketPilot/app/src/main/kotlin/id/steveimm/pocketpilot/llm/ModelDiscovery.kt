package id.steveimm.pocketpilot.llm

import android.util.Log
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.longOrNull

/** Fetches model metadata from the configured server and filters out models that explicitly lack chat or tool support. */
object ModelDiscovery {

    private const val TAG = "ModelDiscovery"
    private const val MAX_DISPLAY_NAME_LEN = 80
    private const val DEFAULT_CONTEXT_WINDOW = 128_000

    /** Heuristic fallback for upstreams whose schema doesn't declare model type. Used only when no structured signal (`model_type`,
     * `endpoints`, `modality`) is available — structured signals always win. */
    private val NON_CHAT_ID_REGEX =
        Regex("(?i)(embedding|whisper|tts|moderation|dall-?e|audio|image-gen|stt|speech)")

    private val json = Json { ignoreUnknownKeys = true }

    /** Parse a `/models` response body into [ModelEntry]s. */
    fun parse(
        body: String,
    ): List<ModelEntry> {
        val root: JsonElement = try {
            json.parseToJsonElement(body)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse /models JSON: ${e.message}")
            return emptyList()
        }
        val items = extractItems(root) ?: return emptyList()
        return items.mapNotNull { parseModel(it) }
    }

    private fun extractItems(root: JsonElement): List<JsonObject>? {
        // Compatible servers commonly wrap entries as `{data: [...]}`. Bare arrays
        // are accepted for upstreams that don't.
        val arr = when (root) {
            is JsonArray -> root
            is JsonObject -> root["data"] as? JsonArray ?: root["models"] as? JsonArray
            else -> null
        } ?: return null
        return arr.mapNotNull { it as? JsonObject }
    }

    private fun parseModel(
        obj: JsonObject,
    ): ModelEntry? {
        val rawId = obj.stringOrNull("id") ?: return null
        val modelId = ModelIdValidator.validate(rawId).getOrElse {
            Log.d(TAG, "Skipping invalid model id")
            return null
        }

        // Tool-calling MANDATORY filter — drop entries that explicitly declare
        // they DON'T support `tools`. Upstreams that omit the field accept.
        if (declaresUnsupportedTools(obj)) return null

        // Non-chat filter — prefer structured upstream fields; fall back to id
        // substring heuristic only when no structured signal is present.
        if (isNonChat(obj, modelId)) return null

        val displayName = sanitizeDisplayName(
            obj.stringOrNull("display_name")
                ?: obj.stringOrNull("name")
                ?: modelId
        )

        val contextWindow = readContextWindow(obj) ?: DEFAULT_CONTEXT_WINDOW


        val created = obj.longOrNull("created") ?: 0L

        return ModelEntry(
            name = modelId,
            displayName = displayName,
            modelId = modelId,
            contextWindow = contextWindow,
            created = created,
        )
    }

    /** Strip ASCII / Unicode control characters from the display name and cap its visible length at [MAX_DISPLAY_NAME_LEN]. Defensive:
     * upstream-supplied text is rendered verbatim in dropdowns and can contain stray control sequences that break layout. */
    internal fun sanitizeDisplayName(raw: String): String {
        val cleaned = raw.filter { ch -> !ch.isISOControl() }.trim()
        if (cleaned.length <= MAX_DISPLAY_NAME_LEN) return cleaned
        return cleaned.substring(0, MAX_DISPLAY_NAME_LEN)
    }

    private fun readContextWindow(obj: JsonObject): Int? {
        obj.intOrNullSafe("context_length")?.let { return it }
        obj.intOrNullSafe("context_size")?.let { return it }
        (obj["top_provider"] as? JsonObject)?.intOrNullSafe("context_length")?.let { return it }
        return null
    }

    private fun declaresUnsupportedTools(obj: JsonObject): Boolean {
        val params = obj["supported_parameters"] as? JsonArray ?: return false
        // Field is present → entry must include "tools" to qualify.
        return !params.containsString("tools")
    }

    private fun isNonChat(obj: JsonObject, modelId: String): Boolean {
        // 1. Prefer structured upstream field: `model_type` (Novita style).
        obj.stringOrNull("model_type")?.lowercase()?.let { type ->
            if (type in NON_CHAT_MODEL_TYPES) return true
            // If a known chat-ish type is declared, trust upstream — skip id heuristic.
            if (type in CHAT_MODEL_TYPES) return false
        }

        // 2. `endpoints` array (Novita) — accept if it lists chat/completions.
        (obj["endpoints"] as? JsonArray)?.let { endpoints ->
            val hasChat = endpoints.any { el ->
                val s = (el as? JsonPrimitive)?.contentOrNull?.lowercase().orEmpty()
                "chat" in s || "completions" in s
            }
            // Decide one way or the other based on the structured field (skip the id heuristic). Drop only when the array is non-empty AND
            // no chat-shape entry is present.
            return if (endpoints.isEmpty()) false else !hasChat
        }

        // 3. `architecture.modality` — `text->text` etc.
        val modality = (obj["architecture"] as? JsonObject)?.stringOrNull("modality")?.lowercase()
        if (modality != null) {
            if ("audio" in modality || "image->" in modality) return true
            if ("text->text" in modality) return false
        }

        // 4. Id-substring fallback when no structured signal made a decision.
        return NON_CHAT_ID_REGEX.containsMatchIn(modelId)
    }

    private val NON_CHAT_MODEL_TYPES = setOf(
        "embedding", "embeddings", "audio", "image", "moderation",
        "speech", "tts", "stt", "rerank", "reranker",
    )

    private val CHAT_MODEL_TYPES = setOf("chat", "llm", "language", "completion")


}

private fun JsonObject.stringOrNull(key: String): String? =
    (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.contentOrNull

private fun JsonObject.intOrNullSafe(key: String): Int? {
    val p = this[key] as? JsonPrimitive ?: return null
    return p.intOrNull ?: p.longOrNull?.toInt()
}

private fun JsonObject.longOrNull(key: String): Long? {
    val p = this[key] as? JsonPrimitive ?: return null
    return p.longOrNull ?: p.intOrNull?.toLong()
}

private fun JsonArray.containsString(needle: String): Boolean =
    any { el -> (el as? JsonPrimitive)?.contentOrNull?.equals(needle, ignoreCase = true) == true }
