package id.steveimm.pocketpilot.agent.definition

import id.steveimm.pocketpilot.tool.ToolName

internal data class AgentDefinition(val systemPrompt: String, val allowedTools: Set<String>) {
    fun resolve(excludedTools: Set<ToolName> = emptySet()): ResolvedAgentDefinition {
        val excluded = excludedTools.map { it.raw }.toSet()
        val tools = allowedTools.filterNot { it in excluded }.toSet()
        return ResolvedAgentDefinition(systemPrompt, tools)
    }
}

internal data class ResolvedAgentDefinition(val systemPrompt: String, val allowedToolNames: Set<String>)
