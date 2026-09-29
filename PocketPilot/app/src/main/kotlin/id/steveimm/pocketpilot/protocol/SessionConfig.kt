package id.steveimm.pocketpilot.protocol

import id.steveimm.pocketpilot.perception.PerceptionConfig

/** SessionConfig - Configuration for an agent session. */
data class SessionConfig(
        /** Delay between actions in milliseconds (for UI to settle) */
        val actionDelayMs: Long = 2000,
        /** Approval mode for tool execution */
        val approvalMode: ApprovalMode = ApprovalMode.SMART,
        /** Model server endpoint captured for this session. */
        val llm: SessionLlmConfig = SessionLlmConfig(),
        /** Enable verbose debug logging */
        val debugMode: Boolean = false,
        /** Persist a full JSONL trace (for inspection_tool) */
        val traceEnabled: Boolean = false,
        /** Trace run id (folder name) for correlating host/device artifacts */
        val traceRunId: String? = null,
        /** Controls which perception modalities (a11y tree, screenshot, both) are active */
        val perceptionConfig: PerceptionConfig = PerceptionConfig.DEFAULT,
        /** Model ID on the configured server. */
        val mainModel: String = "",
        /** Platform mode: real screen (accessibility) or virtual display (Shizuku) */
        val platformMode: PlatformMode = PlatformMode.ACCESSIBILITY,
        /** Tool names to exclude from the agent's allowed tool set (e.g. for eval) */
        val excludedTools: Set<String> = emptySet(),
        /** Eval-only safety net plumbed to [id.steveimm.pocketpilot.agent.AgentExecutionConfig.evalTurnBudget]. Production leaves this
         * null; eval bridge sets it from yaml `max_turns:`. */
        val evalTurnBudget: Int? = null
)

/** Canonical LLM routing config used at runtime. */
data class SessionLlmConfig(val baseUrl: String = "")

/** Platform mode — which display the agent operates on. */
enum class PlatformMode {
        /** Agent operates on the real screen via AccessibilityService. */
        ACCESSIBILITY,
        /** Agent operates on a Shizuku-powered virtual display. */
        VIRTUAL_DISPLAY
}

/** ApprovalMode - How tool execution approvals are handled. */
enum class ApprovalMode {
        /** Always ask user before executing any tool */
        ALWAYS_ASK,
        /** Never ask, auto-approve all tools */
        AUTO_APPROVE,
        /** Smart mode: auto-approve low-risk, ask for high-risk */
        SMART
}
