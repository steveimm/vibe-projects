package id.steveimm.pocketpilot.session

import id.steveimm.pocketpilot.agent.definition.DefaultAgentDefinition
import android.content.Context
import android.util.Log
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.termux.TermuxBridgeManager
import id.steveimm.pocketpilot.termux.TermuxCapabilitySnapshot
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.PolicyEngine
import id.steveimm.pocketpilot.tool.ToolName
import id.steveimm.pocketpilot.tool.ToolRegistry
import id.steveimm.pocketpilot.tool.ToolRouter
import id.steveimm.pocketpilot.tool.impl.TouchTool
import id.steveimm.pocketpilot.tool.impl.TypeTextTool
import id.steveimm.pocketpilot.tool.impl.OpenAppTool
import id.steveimm.pocketpilot.tool.impl.SystemButtonTool
import id.steveimm.pocketpilot.tool.impl.TermuxShellTool
import id.steveimm.pocketpilot.tool.impl.WaitTool
import okhttp3.OkHttpClient

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
        termuxSnapshot: TermuxCapabilitySnapshot = TermuxCapabilitySnapshot.Unavailable,
        excludedTools: Set<String> = emptySet(),
        context: Context? = null
    ): SessionToolingBootstrap {
        val policyEngine = PolicyEngine(
            initialApprovalMode = approvalMode,
            appClassifier = appClassifier
        )
        val allowedToolNames = DefaultAgentDefinition.resolve(
            termuxSnapshot, excludedTools.map { ToolName.from(it) }.toSet(),
        ).allowedToolNames
        val toolRegistry = ToolRegistry().apply {
            registerBuiltInTools(
                allowedToolNames = allowedToolNames,
                context = context
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
        allowedToolNames: Set<String>,
        context: Context?
    ) {
        listOf("tap", "long_press", "swipe").filter { it in allowedToolNames }.forEach { register(TouchTool(it)) }
        if (ToolName.TypeText.raw in allowedToolNames) register(TypeTextTool())
        if (ToolName.SystemButton.raw in allowedToolNames) register(SystemButtonTool())
        if (ToolName.Wait.raw in allowedToolNames) register(WaitTool())
        if (ToolName.OpenApp.raw in allowedToolNames) register(OpenAppTool())
        if (ToolName.TermuxShell.raw in allowedToolNames) registerTermuxShellTool(context)
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
