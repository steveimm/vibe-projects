package id.steveimm.pocketpilot.agent.definition

import id.steveimm.pocketpilot.termux.TermuxBridgeStatus
import id.steveimm.pocketpilot.termux.TermuxCapabilitySnapshot
import id.steveimm.pocketpilot.tool.ToolName
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/** Verifies the LLM allowlist gate for the user pref controlling `browser_script`. */
class DefaultToolsExcludedByPrefTest {

    private val termuxUnavailable = TermuxCapabilitySnapshot(
        available = false,
        enabled = false,
        status = TermuxBridgeStatus.Disabled,
    )

    @Test
    fun `pref off excludes browser_script from helper set`() {
        assertThat(defaultToolsExcludedByPref(browserScriptEnabled = false))
            .containsExactly(ToolName.BrowserScript.raw)
    }

    @Test
    fun `pref on returns empty exclusion set`() {
        assertThat(defaultToolsExcludedByPref(browserScriptEnabled = true)).isEmpty()
    }

    @Test
    fun `pref off causes resolved Default allowlist to drop browser_script`() {
        val excluded = defaultToolsExcludedByPref(browserScriptEnabled = false)
            .map { ToolName.from(it) }.toSet()

        val resolved = DefaultRoleDef.resolve(
            snapshot = termuxUnavailable,
            excludedTools = excluded,
        )

        assertThat(resolved.allowedToolNames).doesNotContain(ToolName.BrowserScript.raw)
        // Other tools must remain — exclusion must not over-prune.
        assertThat(resolved.allowedToolNames).contains("mobile_action")
        assertThat(resolved.allowedToolNames).contains("shell")
    }

    @Test
    fun `pref on causes resolved Default allowlist to include browser_script`() {
        val excluded = defaultToolsExcludedByPref(browserScriptEnabled = true)
            .map { ToolName.from(it) }.toSet()

        val resolved = DefaultRoleDef.resolve(
            snapshot = termuxUnavailable,
            excludedTools = excluded,
        )

        assertThat(resolved.allowedToolNames).contains(ToolName.BrowserScript.raw)
    }
}
