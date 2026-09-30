package id.steveimm.pocketpilot.session

import id.steveimm.pocketpilot.agent.definition.DefaultAgentDefinition
import android.util.Log
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.PolicyEngine
import id.steveimm.pocketpilot.tool.ToolName
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolRouter
import id.steveimm.pocketpilot.tool.impl.TouchTool
import id.steveimm.pocketpilot.tool.impl.TypeTextTool
import id.steveimm.pocketpilot.tool.impl.OpenAppTool
import id.steveimm.pocketpilot.tool.impl.SystemButtonTool
import id.steveimm.pocketpilot.tool.impl.ReadScreenTool

internal data class SessionToolingBootstrap(
        val policyEngine: PolicyEngine,
        val toolRegistry: ToolRegistry,
        val toolRouter: ToolRouter
)

/** Creates policy + session state + built-in tools + router for a session. */
internal object SessionToolingBootstrapper {
    private const val TAG = "SessionToolingBootstrap"

    fun create(
        approvalMode: ApprovalMode,
        appClassifier: AppClassifier,
        excludedTools: Set<String> = emptySet(),
    ): SessionToolingBootstrap {
        val policyEngine = PolicyEngine(
            initialApprovalMode = approvalMode,
            appClassifier = appClassifier
        )
        val allowedToolNames = DefaultAgentDefinition.resolve(
            excludedTools.map { ToolName.from(it) }.toSet(),
        ).allowedToolNames
        val toolRegistry = ToolRegistry().apply {
            registerBuiltInTools(
                allowedToolNames = allowedToolNames
            )
        }

        val toolRouter = ToolRouter(toolRegistry, policyEngine)

        Log.d(TAG, "Created policy/tool stack with ${toolRegistry.size()} built-in tools")

        return SessionToolingBootstrap(
                policyEngine = policyEngine,
                toolRegistry = toolRegistry,
                toolRouter = toolRouter
        )
    }

    private fun ToolRegistry.registerBuiltInTools(
        allowedToolNames: Set<String>
    ) {
        listOf("tap", "long_press", "swipe").filter { it in allowedToolNames }.forEach { register(TouchTool(it)) }
        if (ToolName.TypeText.raw in allowedToolNames) register(TypeTextTool())
        if (ToolName.SystemButton.raw in allowedToolNames) register(SystemButtonTool())
        if (ToolName.ReadScreen.raw in allowedToolNames) register(ReadScreenTool())
        if (ToolName.OpenApp.raw in allowedToolNames) register(OpenAppTool())
    }
}
