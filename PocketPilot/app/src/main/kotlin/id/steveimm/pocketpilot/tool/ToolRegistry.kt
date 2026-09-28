package id.steveimm.pocketpilot.tool

import android.util.Log
import com.openai.models.responses.FunctionTool
import java.util.concurrent.ConcurrentHashMap

/** ToolRegistry - Manages tool discovery, registration, and lookup. */
class ToolRegistry {

    companion object {
        private const val TAG = "ToolRegistry"
    }

    private val tools = ConcurrentHashMap<String, ToolSpec>()

    /** Register a tool. */
    fun register(tool: ToolSpec) {
        if (tools.containsKey(tool.name)) {
            Log.w(TAG, "Overwriting existing tool: ${tool.name}")
        }
        tools[tool.name] = tool
        Log.d(TAG, "Registered tool: ${tool.name}")
    }

    /** Register multiple tools at once. */
    fun registerAll(vararg toolSpecs: ToolSpec) {
        toolSpecs.forEach { register(it) }
    }

    /** Unregister a tool by name. */
    fun unregister(name: String): Boolean {
        val removed = tools.remove(name) != null
        if (removed) {
            Log.d(TAG, "Unregistered tool: $name")
        }
        return removed
    }

    /** Get a tool by name. */
    fun get(name: String): ToolSpec? = tools[name]

    /** Get all registered tool names. */
    fun getNames(): Set<String> = tools.keys.toSet()

    /** Get all registered tools. */
    fun getAll(): List<ToolSpec> = tools.values.toList()

    /** Check if a tool is registered. */
    fun contains(name: String): Boolean = tools.containsKey(name)

    /** Get the count of registered tools. */
    fun size(): Int = tools.size

    /** Clear all registered tools. */
    fun clear() {
        tools.clear()
        Log.d(TAG, "Cleared all tools")
    }

    /** Create a new registry containing only allowed tools, minus explicitly excluded names. */
    fun createFilteredCopy(
        allowedNames: Set<String>,
        excludedNames: Set<String> = emptySet()
    ): ToolRegistry {
        val filtered = ToolRegistry()
        tools.values
            .filter { it.name in allowedNames && it.name !in excludedNames }
            .forEach { filtered.register(it) }
        return filtered
    }

    /** Get a human-readable summary of registered tools. */
    fun getSummary(): String {
        return buildString {
            appendLine("Registered Tools (${tools.size}):")
            tools.values.forEach { tool ->
                appendLine("  - ${tool.name}: ${tool.description}")
            }
        }
    }

    /** Generate FunctionTool objects for the OpenAI Responses API. */
    fun generateResponsesApiTools(filter: ((ToolSpec) -> Boolean)? = null): List<FunctionTool> {
        return tools.values
            .filter { filter?.invoke(it) != false }
            .map { tool ->
                val parameters = FunctionTool.Parameters.builder()
                    .putAllAdditionalProperties(jsonObjectToJsonValueMap(tool.parameterSchema))
                    .build()
                FunctionTool.builder()
                    .name(tool.name)
                    .description(tool.description)
                    .parameters(parameters)
                    // strict mode disabled - it requires ALL properties in required array,
                    // which doesn't work with optional parameters like duration_ms
                    .strict(false)
                    .build()
            }
    }

}
