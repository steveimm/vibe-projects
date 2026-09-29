package id.steveimm.pocketpilot.agent.cognition.policy

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.agent.ToolCallRequest
import id.steveimm.pocketpilot.agent.TurnResult
import org.json.JSONObject
import org.junit.Test

class TurnToolPolicyTest {
    private val engine = TurnToolPolicy()

    @Test
    fun termuxShell_preserves_order_before_mobileAction() {
        val calls =
                listOf(
                        toolCall(name = "termux_shell"),
                        toolCall(name = "mobile_action")
                )

        val result = engine.arbitrateToolCalls(calls)

        assertThat(result.selectedToolCalls.map { it.name })
                .containsExactly("termux_shell", "mobile_action")
                .inOrder()
    }

    @Test
    fun termuxShell_preserves_order_after_mobileAction() {
        val calls =
                listOf(
                        toolCall(name = "mobile_action"),
                        toolCall(name = "termux_shell")
                )

        val result = engine.arbitrateToolCalls(calls)

        assertThat(result.selectedToolCalls.map { it.name })
                .containsExactly("mobile_action", "termux_shell")
                .inOrder()
    }

    @Test
    fun `decideCompletion defers completion when screen action exists`() {
        val calls =
                listOf(
                        toolCall(
                                name = "complete_task",
                                arguments = JSONObject("""{"answer":"done"}""")
                        ),
                        toolCall(name = "mobile_action")
                )
        val turnResult = TurnResult(content = "text", toolCalls = calls, isComplete = true)
        val arbitration = engine.arbitrateToolCalls(calls)

        val decision = engine.decideCompletion(turnResult, arbitration)

        assertThat(decision.shouldComplete).isFalse()
        assertThat(decision.summary).isNull()
        assertThat(decision.success).isFalse()
    }

    @Test
    fun `decideCompletion uses answer from complete_task when available`() {
        val calls =
                listOf(
                        toolCall(
                                name = "complete_task",
                                arguments = JSONObject("""{"answer":"final answer"}""")
                        )
                )
        val turnResult = TurnResult(content = "fallback", toolCalls = calls, isComplete = true)
        val arbitration = engine.arbitrateToolCalls(calls)

        val decision = engine.decideCompletion(turnResult, arbitration)

        assertThat(decision.shouldComplete).isTrue()
        assertThat(decision.summary).isEqualTo("final answer")
        assertThat(decision.success).isTrue()
    }

    @Test
    fun `decideCompletion marks status failure as unsuccessful completion`() {
        val calls =
                listOf(
                        toolCall(
                                name = "complete_task",
                                arguments = JSONObject("""{"status":"failure","answer":"cannot finish"}""")
                        )
                )
        val turnResult = TurnResult(content = "fallback", toolCalls = calls, isComplete = true)
        val arbitration = engine.arbitrateToolCalls(calls)

        val decision = engine.decideCompletion(turnResult, arbitration)

        assertThat(decision.shouldComplete).isTrue()
        assertThat(decision.success).isFalse()
        assertThat(decision.summary).isEqualTo("cannot finish")
    }

    private fun toolCall(name: String, arguments: JSONObject = JSONObject()): ToolCallRequest {
        return ToolCallRequest(id = "call-$name", name = name, arguments = arguments)
    }
}
