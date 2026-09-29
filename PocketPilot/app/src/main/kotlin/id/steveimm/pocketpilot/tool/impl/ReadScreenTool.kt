package id.steveimm.pocketpilot.tool.impl

import id.steveimm.pocketpilot.tool.*
import kotlinx.coroutines.delay
import org.json.JSONObject

class ReadScreenTool : ToolSpec {
    override val name = "read_screen"
    override val description = "Read the current phone screen. Use when the request needs screen information. " +
        "Optional delay_ms waits for an app transition or loading before the fresh screenshot (default 0, max 30000)."
    override val parameterSchema = parameterObject(
        mapOf("delay_ms" to integerParameter("Delay before reading the screen, in milliseconds", 0, 30000)), emptyList(),
    )
    override fun validate(params: JSONObject): ValidationResult = validateToolParameters(params, parameterSchema)
    override fun createInvocation(params: JSONObject): ToolInvocation = object : ToolInvocation {
        override val toolName = name
        override val params = params
        override fun getDescription() = "Read current screen"
        override suspend fun execute(context: ToolExecutionContext): ToolExecutionResult {
            if (context.isCancelled()) return ToolExecutionResult.Cancelled()
            delay(params.optLong("delay_ms", 0))
            if (context.isCancelled()) return ToolExecutionResult.Cancelled()
            return textToolSuccess("The current screen observation follows.")
        }
    }
}
