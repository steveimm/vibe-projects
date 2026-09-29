package id.steveimm.pocketpilot.tool.impl

import id.steveimm.pocketpilot.platform.UIAction
import id.steveimm.pocketpilot.tool.ToolInvocation
import id.steveimm.pocketpilot.tool.ToolSpec
import id.steveimm.pocketpilot.tool.ValidationResult
import id.steveimm.pocketpilot.tool.handlers.UIActionInvocation
import org.json.JSONArray
import org.json.JSONObject

/** WaitTool - deterministic wait without screen targeting. */
class WaitTool : ToolSpec {
    companion object {
        private const val DEFAULT_WAIT_MS = 1000L
        private const val MAX_WAIT_MS = 30_000L
    }

    override val name: String = "wait"

    override val description: String = """
Wait for UI updates to settle when transitions, animations, or async loading are in progress.
""".trimIndent()

    override val parameterSchema: JSONObject = JSONObject().apply {
        put("type", "object")
        put(
            "properties",
            JSONObject().apply {
                put(
                    "duration_ms",
                    JSONObject().apply {
                        put("type", "integer")
                        put("minimum", 0)
                        put("maximum", MAX_WAIT_MS)
                        put("description", "Wait duration in milliseconds (default 1000, max 30000)")
                    }
                )
            }
        )
        put("required", JSONArray())
        put("additionalProperties", false)
    }

    override fun validate(params: JSONObject): ValidationResult {
        val durationMs = params.optLong("duration_ms", DEFAULT_WAIT_MS)
        if (durationMs < 0) {
            return ValidationResult.Invalid("duration_ms must be non-negative")
        }
        if (durationMs > MAX_WAIT_MS) {
            return ValidationResult.Invalid("duration_ms must be <= $MAX_WAIT_MS")
        }
        return ValidationResult.Valid
    }

    override fun createInvocation(params: JSONObject): ToolInvocation {
        val durationMs = params.optLong("duration_ms", DEFAULT_WAIT_MS)
        return UIActionInvocation(
            toolName = name,
            params = params,
            description = "Wait ${durationMs}ms for UI to settle",
            uiAction = UIAction.Wait(durationMs)
        )
    }
}
