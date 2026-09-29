package id.steveimm.pocketpilot.tool.impl

import id.steveimm.pocketpilot.platform.SystemButtonType
import id.steveimm.pocketpilot.platform.UIAction
import id.steveimm.pocketpilot.tool.ToolInvocation
import id.steveimm.pocketpilot.tool.ToolSpec
import id.steveimm.pocketpilot.tool.ValidationResult
import id.steveimm.pocketpilot.tool.handlers.UIActionInvocation
import org.json.JSONArray
import org.json.JSONObject

/** SystemButtonTool - deterministic system-key actions without screen targeting. */
class SystemButtonTool : ToolSpec {
    companion object {
        private val VALID_BUTTONS = listOf("back", "home", "enter", "recents")
    }

    override val name: String = "system_button"

    override val description: String = """
Press an Android system button (no element targeting needed).
Buttons: back, home, enter (IME enter to focused field), recents.
""".trimIndent()

    override val parameterSchema: JSONObject = JSONObject().apply {
        put("type", "object")
        put(
            "properties",
            JSONObject().apply {
                put(
                    "button",
                    JSONObject().apply {
                        put("type", "string")
                        put("enum", JSONArray(VALID_BUTTONS))
                        put("description", "System button to press")
                    }
                )
            }
        )
        put("required", JSONArray(listOf("button")))
        put("additionalProperties", false)
    }

    override fun validate(params: JSONObject): ValidationResult {
        if (!params.has("button")) {
            return ValidationResult.Invalid("Missing required parameter: button")
        }
        val button = params.optString("button", "").lowercase()
        if (button !in VALID_BUTTONS) {
            return ValidationResult.Invalid("button must be one of: ${VALID_BUTTONS.joinToString()}")
        }
        return ValidationResult.Valid
    }

    override fun createInvocation(params: JSONObject): ToolInvocation {
        val button = params.getString("button").lowercase()
        val buttonType = when (button) {
            "back" -> SystemButtonType.BACK
            "home" -> SystemButtonType.HOME
            "enter" -> SystemButtonType.ENTER
            "recents" -> SystemButtonType.RECENTS
            else -> error("Unreachable: validated in validate()")
        }
        return UIActionInvocation(
            toolName = name,
            params = params,
            description = "Press $button button",
            uiAction = UIAction.SystemButton(buttonType)
        )
    }
}
