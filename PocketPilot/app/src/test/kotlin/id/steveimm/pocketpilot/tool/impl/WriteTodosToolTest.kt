package id.steveimm.pocketpilot.tool.impl

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.protocol.TodoStatus
import id.steveimm.pocketpilot.session.TodoState
import id.steveimm.pocketpilot.test.FakeAndroidPlatform
import id.steveimm.pocketpilot.tool.ToolExecutionContext
import id.steveimm.pocketpilot.tool.ToolExecutionResult
import id.steveimm.pocketpilot.tool.ValidationResult
import kotlinx.coroutines.test.runTest
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Test

class WriteTodosToolTest {

    @Test
    fun `missing todos is invalid`() {
        val tool = WriteTodosTool(TodoState())

        val result = tool.validate(JSONObject())

        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `invalid status is rejected`() {
        val tool = WriteTodosTool(TodoState())
        val params = JSONObject().put("todos", JSONArray().put(
            JSONObject()
                .put("description", "test")
                .put("status", "maybe")
        ))

        val result = tool.validate(params)

        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `empty description is rejected`() {
        val tool = WriteTodosTool(TodoState())
        val params = JSONObject().put("todos", JSONArray().put(
            JSONObject()
                .put("description", " ")
                .put("status", "pending")
        ))

        val result = tool.validate(params)

        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `multiple in progress is invalid`() {
        val tool = WriteTodosTool(TodoState())
        val params = JSONObject().put("todos", JSONArray().apply {
            put(JSONObject().put("description", "a").put("status", "in_progress"))
            put(JSONObject().put("description", "b").put("status", "in_progress"))
        })

        val result = tool.validate(params)

        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `execute updates state`() = runTest {
        val state = TodoState()
        val tool = WriteTodosTool(state)
        val params = JSONObject().put("todos", JSONArray().apply {
            put(JSONObject().put("description", "task").put("status", "pending"))
        })

        val invocation = tool.createInvocation(params)
        val result = invocation.execute(buildContext())

        assertThat(result).isInstanceOf(ToolExecutionResult.Success::class.java)
        assertThat(state.get()).hasSize(1)
        assertThat(state.get().single().status).isEqualTo(TodoStatus.PENDING)
    }

    @Test
    fun `execute returns compact plan updated output`() = runTest {
        val tool = WriteTodosTool(TodoState())
        val params = JSONObject().put("todos", JSONArray().apply {
            put(JSONObject().put("description", "task a").put("status", "pending"))
            put(JSONObject().put("description", "task b").put("status", "completed"))
        })

        val invocation = tool.createInvocation(params)
        val result = invocation.execute(buildContext())

        assertThat(result).isInstanceOf(ToolExecutionResult.Success::class.java)
        val success = result as ToolExecutionResult.Success
        assertThat(success.output).isEqualTo("Plan updated (2 items).")
    }

    @Test
    fun `schema documents agent thought plan change rationale`() {
        val tool = WriteTodosTool(TodoState())

        val description = tool.parameterSchema
            .getJSONObject("properties")
            .getJSONObject("agent_thought")
            .getString("description")

        assertThat(description).contains("changing the plan")
    }

    @Test
    fun `description includes discovery and small task guidance`() {
        val tool = WriteTodosTool(TodoState())

        assertThat(tool.description).contains("new requirements")
        assertThat(tool.description).contains("1-2 actions")
    }

    private fun buildContext(): ToolExecutionContext {
        return object : ToolExecutionContext {
            override val platform = FakeAndroidPlatform()
            override val currentSnapshot = null
            override fun isCancelled(): Boolean = false
        }
    }
}
