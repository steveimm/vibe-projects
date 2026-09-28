package id.steveimm.pocketpilot.tool

import org.json.JSONObject
import java.util.concurrent.atomic.AtomicBoolean

/** ToolSpec - Specification for a tool that can be invoked by the agent. */
interface ToolSpec {
    /** Unique name of the tool (used in LLM function calling) */
    val name: String

    /** Human-readable description for the LLM */
    val description: String

    /** JSON Schema for the tool's parameters */
    val parameterSchema: JSONObject

    /** Validate the parameters before creating an invocation. */
    fun validate(params: JSONObject): ValidationResult

    /** Create an executable invocation from validated parameters. */
    fun createInvocation(params: JSONObject): ToolInvocation
}

/** ValidationResult - Result of validating tool parameters. */
sealed interface ValidationResult {
    /** Parameters are valid */
    data object Valid : ValidationResult

    /** Parameters are invalid */
    data class Invalid(
        val errors: List<String>
    ) : ValidationResult {
        constructor(error: String) : this(listOf(error))
    }
}

/** ToolInvocation - A validated, ready-to-execute tool call. */
interface ToolInvocation {
    /** The tool this invocation is for */
    val toolName: String

    /** The parameters for this invocation */
    val params: JSONObject

    /** Get a human-readable description of what this invocation will do. Used for approval dialogs and logging. */
    fun getDescription(): String

    /** Execute the tool invocation. */
    suspend fun execute(context: ToolExecutionContext): ToolExecutionResult
}

/** ToolExecutionContext - Context provided to tool invocations during execution. */
interface ToolExecutionContext {
    /** Call id assigned by ToolRouter, useful for cross-component correlation. Nullable for tests or custom execution contexts. */
    val callId: String? get() = null

    /** Access to platform operations */
    val platform: id.steveimm.pocketpilot.platform.AndroidPlatform

    /** Current screen snapshot (if available) */
    val currentSnapshot: id.steveimm.pocketpilot.model.ScreenSnapshot?

    /** App classifier for privacy gating (masks BLOCKED app observations). */
    val appClassifier: id.steveimm.pocketpilot.tool.AppClassifier? get() = null

    /** Check if execution should be cancelled */
    fun isCancelled(): Boolean
}

/** ToolExecutionResult - Result of executing a tool. */
sealed interface ToolExecutionResult {
    /** Execution succeeded */
    data class Success(
        val output: String,
        val observation: ToolObservation? = null
    ) : ToolExecutionResult

    /** Execution failed */
    data class Failure(
        val error: String,
        val exception: Throwable? = null
    ) : ToolExecutionResult

    /** Execution was cancelled */
    data class Cancelled(
        val reason: String = "Cancelled"
    ) : ToolExecutionResult
}

/** ToolObservation - Post-action observation captured after tool execution. */
sealed interface ToolObservation {
    /** Screen state after action (for UI tools) */
    data class ScreenState(
        val accessibilityTree: String,
        val elementCount: Int,
        val summary: String = "",
        /** The actual snapshot object for subsequent tool executions */
        val snapshot: id.steveimm.pocketpilot.model.ScreenSnapshot? = null
    ) : ToolObservation

    /** Text output for non-UI tools */
    data class TextOutput(val content: String) : ToolObservation
}

/** Standard success result for text-only tools. */
fun textToolSuccess(output: String): ToolExecutionResult.Success =
        ToolExecutionResult.Success(
                output = output,
                observation = ToolObservation.TextOutput(output)
        )

/** Per-call cancellation token. ToolRouter creates one per execute() call. Tools observe cancellation via
 * ToolExecutionContext.isCancelled(), which delegates to this token. */
class CancellationToken {
    private val cancelled = AtomicBoolean(false)
    fun cancel() { cancelled.set(true) }
    fun isCancelled(): Boolean = cancelled.get()
}

/** Appends a reason suffix in a consistent format. */
fun appendReason(base: String, reason: String): String =
        reason.takeIf { it.isNotBlank() }?.let { "$base (reason: $it)" } ?: base
