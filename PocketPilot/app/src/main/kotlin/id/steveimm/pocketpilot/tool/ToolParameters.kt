package id.steveimm.pocketpilot.tool

import org.json.JSONArray
import org.json.JSONObject

internal fun parameterObject(properties: Map<String, JSONObject>, required: List<String> = properties.keys.toList()): JSONObject =
    JSONObject().put("type", "object").put("properties", JSONObject(properties))
        .put("required", JSONArray(required)).put("additionalProperties", false)

internal fun integerParameter(description: String, minimum: Int, maximum: Int): JSONObject =
    JSONObject().put("type", "integer").put("description", description).put("minimum", minimum).put("maximum", maximum)

/** Validate the schema subset used by the tools before any coercing JSON getters run. */
internal fun validateToolParameters(params: JSONObject, schema: JSONObject): ValidationResult {
    val errors = mutableListOf<String>()
    val properties = schema.optJSONObject("properties") ?: JSONObject()
    val required = schema.optJSONArray("required") ?: JSONArray()
    for (index in 0 until required.length()) {
        val name = required.getString(index)
        if (!params.has(name)) errors += "Missing required parameter: $name"
    }
    for (name in params.keys()) {
        val property = properties.optJSONObject(name)
        if (property == null) {
            if (schema.opt("additionalProperties") == false) errors += "Unknown parameter: $name"
        } else {
            validateParameter(name, params.opt(name), property, errors)
        }
    }
    return if (errors.isEmpty()) ValidationResult.Valid else ValidationResult.Invalid(errors)
}

private fun validateParameter(path: String, value: Any?, schema: JSONObject, errors: MutableList<String>) {
    val type = schema.optString("type")
    val validType = when (type) {
        "string" -> value is String
        "integer" -> value is Number && value.toDouble().isFinite() && value.toDouble() % 1.0 == 0.0
        "boolean" -> value is Boolean
        "object" -> value is JSONObject
        "array" -> value is JSONArray
        else -> false
    }
    if (!validType) {
        val received = when (value) {
            null, JSONObject.NULL -> "null"
            is String -> "string"
            is Number -> "number"
            is Boolean -> "boolean"
            is JSONArray -> "array"
            else -> "object"
        }
        errors += "$path must be $type (received $received)"
        return
    }
    val choices = schema.optJSONArray("enum")
    if (choices != null && (0 until choices.length()).none { choices.get(it) == value }) {
        errors += "$path must be one of $choices"
    }
    if (value is Number) {
        if (schema.has("minimum") && value.toDouble() < schema.getDouble("minimum")) {
            errors += "$path must be >= ${schema.get("minimum")}"
        }
        if (schema.has("maximum") && value.toDouble() > schema.getDouble("maximum")) {
            errors += "$path must be <= ${schema.get("maximum")}"
        }
    }
    if (value is JSONArray) {
        val min = schema.optInt("minItems", 0)
        val max = schema.optInt("maxItems", Int.MAX_VALUE)
        if (value.length() !in min..max) errors += "$path must contain ${if (min == max) "$min" else "$min..$max"} items"
        schema.optJSONObject("items")?.let { itemSchema ->
            for (index in 0 until value.length()) validateParameter("$path[$index]", value.opt(index), itemSchema, errors)
        }
    }
}
