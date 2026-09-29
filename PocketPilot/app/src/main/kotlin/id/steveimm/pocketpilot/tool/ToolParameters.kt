package id.steveimm.pocketpilot.tool

import org.json.JSONArray
import org.json.JSONObject

internal fun parameterObject(properties: Map<String, JSONObject>, required: List<String> = properties.keys.toList()): JSONObject =
    JSONObject().put("type", "object").put("properties", JSONObject(properties))
        .put("required", JSONArray(required)).put("additionalProperties", false)

internal fun integerParameter(description: String, minimum: Int, maximum: Int): JSONObject =
    JSONObject().put("type", "integer").put("description", description).put("minimum", minimum).put("maximum", maximum)

/** Validate the schema subset used by the phone tools before any coercing JSON getters run. */
internal fun validateToolParameters(params: JSONObject, schema: JSONObject): ValidationResult {
    val properties = schema.optJSONObject("properties") ?: JSONObject()
    val required = schema.optJSONArray("required") ?: JSONArray()
    for (index in 0 until required.length()) {
        val name = required.getString(index)
        if (!params.has(name)) return ValidationResult.Invalid("Missing required parameter: $name")
    }
    for (name in params.keys()) {
        val property = properties.optJSONObject(name)
        if (property == null) {
            if (schema.opt("additionalProperties") == false) return ValidationResult.Invalid("Unknown parameter: $name")
            continue
        }
        val value = params.opt(name)
        val validType = when (property.optString("type")) {
            "string" -> value is String
            "integer" -> value is Number && value.toDouble().isFinite() && value.toDouble() % 1.0 == 0.0
            "boolean" -> value is Boolean
            "object" -> value is JSONObject
            else -> false
        }
        if (!validType) return ValidationResult.Invalid("$name must be ${property.optString("type")}")
        val choices = property.optJSONArray("enum")
        if (choices != null && (0 until choices.length()).none { choices.get(it) == value }) {
            return ValidationResult.Invalid("$name must be one of $choices")
        }
        if (value is Number) {
            if (property.has("minimum") && value.toDouble() < property.getDouble("minimum")) {
                return ValidationResult.Invalid("$name must be >= ${property.get("minimum")}")
            }
            if (property.has("maximum") && value.toDouble() > property.getDouble("maximum")) {
                return ValidationResult.Invalid("$name must be <= ${property.get("maximum")}")
            }
        }
    }
    return ValidationResult.Valid
}
