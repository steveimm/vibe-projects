package id.steveimm.pocketpilot.test

import id.steveimm.pocketpilot.llm.ModelCatalog
import id.steveimm.pocketpilot.llm.ModelEntry
import org.json.JSONObject

fun testModelCatalog(source: String): ModelCatalog {
    val raw = JSONObject(source)
    return ModelCatalog.fromEntries(raw.keys().asSequence().map { name ->
        val value = raw.getJSONObject(name)
        ModelEntry(
            name = name,
            displayName = value.optString("display_name", name),
            modelId = value.optString("model_id", name),
            contextWindow = value.optInt("context_window", ModelEntry.DEFAULT_CONTEXT_WINDOW),
        )
    }.toList())
}
