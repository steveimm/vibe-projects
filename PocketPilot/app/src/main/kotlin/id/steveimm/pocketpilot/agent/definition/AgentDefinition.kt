package id.steveimm.pocketpilot.agent.definition

import id.steveimm.pocketpilot.termux.TermuxCapabilitySnapshot
import id.steveimm.pocketpilot.tool.ToolName

internal data class AgentDefinition(val systemPrompt: String, val allowedTools: Set<String>) {
    fun resolve(snapshot: TermuxCapabilitySnapshot, excludedTools: Set<ToolName> = emptySet()): ResolvedAgentDefinition {
        val excluded = excludedTools.map { it.raw }.toSet()
        val tools = allowedTools.filterNot { it in excluded }.toMutableSet()
        if (snapshot.available && ToolName.TermuxShell !in excludedTools) tools += ToolName.TermuxShell.raw
        val prompt = if (ToolName.TermuxShell.raw in tools) systemPrompt + "\n\n" + WORKSPACE_SHELL_PROMPT_SECTION else systemPrompt
        return ResolvedAgentDefinition(prompt, tools)
    }
}

internal data class ResolvedAgentDefinition(val systemPrompt: String, val allowedToolNames: Set<String>)
