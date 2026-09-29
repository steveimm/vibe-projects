package id.steveimm.pocketpilot.agent.definition

import id.steveimm.pocketpilot.termux.TermuxBridgeStatus
import id.steveimm.pocketpilot.termux.TermuxCapabilitySnapshot
import id.steveimm.pocketpilot.tool.ToolName
import com.google.common.truth.Truth.assertThat
import org.junit.Test

class AgentDefinitionTest {

    @Test
    fun `available snapshot exposes termux shell and workspace prompt`() {
        val resolved = DefaultAgentDefinition.resolve(availableSnapshot)

        assertThat(resolved.allowedToolNames).contains(ToolName.TermuxShell.raw)
        assertThat(resolved.systemPrompt).contains("Workspace Shell")
    }

    @Test
    fun `unavailable snapshot hides termux shell and workspace prompt`() {
        val resolved = DefaultAgentDefinition.resolve(unavailableSnapshot)

        assertThat(resolved.allowedToolNames).doesNotContain(ToolName.TermuxShell.raw)
        assertThat(resolved.systemPrompt).doesNotContain("Workspace Shell")
    }

    @Test
    fun `excluded termux shell hides tool and workspace prompt`() {
        val resolved = DefaultAgentDefinition.resolve(
            snapshot = availableSnapshot,
            excludedTools = setOf(ToolName.TermuxShell)
        )

        assertThat(resolved.allowedToolNames).doesNotContain(ToolName.TermuxShell.raw)
        assertThat(resolved.systemPrompt).doesNotContain("Workspace Shell")
    }

    private companion object {
        val availableSnapshot = TermuxCapabilitySnapshot(
            available = true,
            enabled = true,
            status = TermuxBridgeStatus.Ready
        )
        val unavailableSnapshot = TermuxCapabilitySnapshot(
            available = false,
            enabled = true,
            status = TermuxBridgeStatus.Disabled
        )
    }
}
