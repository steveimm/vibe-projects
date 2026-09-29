package id.steveimm.pocketpilot.session

import id.steveimm.pocketpilot.agent.definition.DefaultAgentDefinition
import android.content.Context
import android.util.Log
import id.steveimm.pocketpilot.agent.cognition.skills.AgentSkillManager
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.termux.TermuxBridgeManager
import id.steveimm.pocketpilot.termux.TermuxCapabilitySnapshot
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.PolicyEngine
import id.steveimm.pocketpilot.tool.ToolName
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolRouter
import id.steveimm.pocketpilot.tool.impl.ActivateSkillTool
import id.steveimm.pocketpilot.tool.impl.CompleteTaskTool
import id.steveimm.pocketpilot.tool.impl.MobileActionTool
import id.steveimm.pocketpilot.tool.impl.OpenAppTool
import id.steveimm.pocketpilot.tool.impl.ScratchpadTool
import id.steveimm.pocketpilot.tool.impl.SystemButtonTool
import id.steveimm.pocketpilot.tool.impl.TermuxShellTool
import id.steveimm.pocketpilot.tool.impl.WaitTool
import id.steveimm.pocketpilot.tool.impl.WriteTodosTool
import okhttp3.OkHttpClient

internal data class SessionToolingBootstrap(
        val policyEngine: PolicyEngine,
        val sessionState: AgentSessionState,
        val toolRegistry: ToolRegistry,
        val toolRouter: ToolRouter
)

/** Creates policy + session state + built-in tools + router for a session. */
internal object SessionToolingBootstrapper {
    private const val TAG = "SessionToolingBootstrap"

    fun create(
        approvalMode: ApprovalMode,
        appClassifier: AppClassifier,
        agentSkillManager: AgentSkillManager? = null,
        termuxSnapshot: TermuxCapabilitySnapshot = TermuxCapabilitySnapshot.Unavailable,
        excludedTools: Set<String> = emptySet(),
        context: Context? = null
    ): SessionToolingBootstrap {
        val policyEngine = PolicyEngine(
            initialApprovalMode = approvalMode,
            appClassifier = appClassifier
        )
        val sessionState = AgentSessionState()
        val allowedToolNames = DefaultAgentDefinition.resolve(
            termuxSnapshot, excludedTools.map { ToolName.from(it) }.toSet(),
        ).allowedToolNames
        val toolRegistry = ToolRegistry().apply {
            registerBuiltInTools(
                sessionState = sessionState,
                allowedToolNames = allowedToolNames,
                context = context
            )
        }

        if (
            ToolName.ActivateSkill.raw in allowedToolNames &&
                agentSkillManager != null &&
                agentSkillManager.catalogPrompt() != null
        ) {
            toolRegistry.register(ActivateSkillTool(agentSkillManager))
            Log.d(TAG, "Registered ActivateSkillTool (catalog non-empty)")
        }

        val toolRouter = ToolRouter(toolRegistry, policyEngine)

        Log.d(TAG, "Created policy/tool stack with ${toolRegistry.size()} built-in tools")

        return SessionToolingBootstrap(
                policyEngine = policyEngine,
                sessionState = sessionState,
                toolRegistry = toolRegistry,
                toolRouter = toolRouter
        )
    }

    private fun ToolRegistry.registerBuiltInTools(
        sessionState: AgentSessionState,
        allowedToolNames: Set<String>,
        context: Context?
    ) {
        if (ToolName.CompleteTask.raw in allowedToolNames) register(CompleteTaskTool())
        if (ToolName.MobileAction.raw in allowedToolNames) register(MobileActionTool())
        if (ToolName.SystemButton.raw in allowedToolNames) register(SystemButtonTool())
        if (ToolName.Wait.raw in allowedToolNames) register(WaitTool())
        if (ToolName.OpenApp.raw in allowedToolNames) register(OpenAppTool())
        if (ToolName.TermuxShell.raw in allowedToolNames) registerTermuxShellTool(context)
        if (ToolName.WriteTodos.raw in allowedToolNames) register(WriteTodosTool(sessionState.todos))
        if (ToolName.Scratchpad.raw in allowedToolNames) register(ScratchpadTool(sessionState.scratchpad))
    }

    private fun ToolRegistry.registerTermuxShellTool(context: Context?) {
        if (context != null) {
            TermuxBridgeManager.get(context)
        } else {
            Log.w(TAG, "Registering termux_shell without a Context; bridge manager not touched")
        }

        register(TermuxShellTool(httpClient = OkHttpClient()))
    }
}
