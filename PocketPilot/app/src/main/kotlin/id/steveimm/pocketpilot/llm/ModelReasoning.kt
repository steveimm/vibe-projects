package id.steveimm.pocketpilot.llm

import com.openai.core.JsonValue
import kotlinx.serialization.Serializable

/** Preserve the server's reasoning field when replaying an assistant turn. */
@Serializable
data class ModelReasoning(val content: String, val field: String = "reasoning")

internal fun readModelReasoning(fields: Map<String, JsonValue>): ModelReasoning? =
    listOf("reasoning", "reasoning_content").firstNotNullOfOrNull { field ->
        fields[field]?.asString()?.orElse(null)?.takeIf { it.isNotEmpty() }?.let { ModelReasoning(it, field) }
    }
