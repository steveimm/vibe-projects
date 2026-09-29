package id.steveimm.pocketpilot.agent

import android.util.Log
import id.steveimm.pocketpilot.agent.cognition.policy.ToolArbitrationResult
import id.steveimm.pocketpilot.agent.cognition.policy.TurnToolPolicy
import id.steveimm.pocketpilot.agent.cognition.prompt.PromptBuilder
import id.steveimm.pocketpilot.agent.cognition.prompt.TurnObservation
import id.steveimm.pocketpilot.history.Compactor
import id.steveimm.pocketpilot.history.MessageKind
import id.steveimm.pocketpilot.history.ResponseItem
import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.protocol.TurnPhase
import id.steveimm.pocketpilot.session.SessionServices
import id.steveimm.pocketpilot.tool.ToolName
import id.steveimm.pocketpilot.trace.AgentTrace
import id.steveimm.pocketpilot.trace.ArbitrationDecision
import id.steveimm.pocketpilot.trace.DropReason
import id.steveimm.pocketpilot.trace.DroppedToolCall

internal data class PlanningPhaseOutput(
        val turnResult: TurnResult,
        val arbitration: ToolArbitrationResult
)

internal class TurnPlanningPhaseRunner(
        private val config: AgentExecutionConfig,
        private val services: SessionServices,
        private val eventDispatcher: AgentEventDispatcher,
        private val trace: AgentTrace,
        private val turnPolicyEngine: TurnToolPolicy,
        private val compactor: Compactor? = null
) {
        companion object {
                private const val TAG = "TurnPlanningPhase"
        }
        private val modelResolver =
                AgentModelResolver(
                        sessionLlmClient = services.llmClient,
                        modelCatalog = services.modelCatalog,
                        llmClientFactory = services.llmClientFactory
                )

        suspend fun runPlanningPhase(
                turnId: String,
                turnNumber: Int,
                snapshot: ScreenSnapshot,
                currentPackageName: String?,
                warnings: List<String>
        ): PlanningPhaseOutput {
                eventDispatcher.turnPhaseChanged(turnId, TurnPhase.PLANNING)
                eventDispatcher.status("🧠 Thinking...")

                val model = modelResolver.resolve(config.modelName)

                val turn =
                        Turn(
                                toolRegistry = services.toolRegistry,
                                llmClient = model.llmClient,
                                allowedToolNames = config.allowedToolNames,
                                compactor = compactor,
                                historyManager =
                                        if (compactor != null) services.historyManager else null,
                                currentGoal = if (compactor != null) ({ config.goal }) else null
                        )
                val systemPrompt =
                        requireNotNull(config.systemPrompt) {
                                "System prompt must be provided by AgentDefinition."
                        }

                // Canonical observation — computed once, consumed by prompt and history.
                val observation = TurnObservation.capture(
                        snapshot = snapshot,
                        perceptionConfig = services.config.perceptionConfig
                )

                val promptBuilder =
                        PromptBuilder(
                                historyManager = services.historyManager,
                                supportsVision = model.supportsVision
                        )
                val inputItems =
                        promptBuilder.buildInputItems(
                                observation = observation,
                                warnings = warnings,
                                turnNumber = turnNumber,
                        )

                // Record screen observation for future turns.
                // Uses the same canonical screenBlock — no ordering dependency.
                services.historyManager.addItem(
                        ResponseItem.Message(
                                kind = MessageKind.SCREEN_OBSERVATION,
                                content = observation.screenBlock.trim()
                        )
                )

                trace.llmRequest(
                        turnId = turnId,
                        turnNumber = turnNumber,
                        snapshot = snapshot,
                        systemPrompt = systemPrompt,
                        userContextText = "(built by PromptBuilder)",
                        history = services.historyManager.forPrompt(),
                        inputItems = inputItems,
                        modelName = config.modelName,
                        modelId = model.modelId
                )

                val reasoning = StringBuilder()
                var turnResult: TurnResult? = null
                var streamError: Throwable? = null
                turn.runStreaming(
                                systemPrompt = systemPrompt,
                                inputItems = inputItems,
                                model = model.modelId,
                                rebuildInputItems = {
                                        Log.i(
                                                TAG,
                                                "Rebuilding prompt input items after reactive compaction"
                                        )
                                        promptBuilder.buildInputItems(
                                                observation = observation,
                                                warnings = warnings,
                                                turnNumber = turnNumber,
                                        )
                                }
                        )
                        .collect { event ->
                                when (event) {
                                        is TurnStreamEvent.ReasoningDelta -> {
                                                reasoning.append(event.delta)
                                                eventDispatcher.reasoningDelta(turnId, event.delta)
                                        }
                                        is TurnStreamEvent.TextDelta ->
                                                eventDispatcher.messageDelta(turnId, event.text)
                                        is TurnStreamEvent.ToolCallReceived ->
                                                Log.d(
                                                        TAG,
                                                        "Turn $turnNumber: Received tool call: ${event.toolCall.name}"
                                                )
                                        is TurnStreamEvent.Complete -> {
                                                turnResult = event.result
                                                Log.d(
                                                        TAG,
                                                        "Turn $turnNumber: Stream complete, isComplete=${event.result.isComplete}"
                                                )
                                        }
                                        is TurnStreamEvent.Error -> {
                                                streamError = event.error
                                                Log.e(
                                                        TAG,
                                                        "Turn $turnNumber: Stream error",
                                                        event.error
                                                )
                                        }
                                }
                        }

                streamError?.let { throw it }
                val result = turnResult ?: throw RuntimeException("Stream completed without result")

                Log.d(TAG, "Turn $turnNumber: LLM response: ${result.content?.take(200)}...")
                Log.d(TAG, "Turn $turnNumber: Tool calls: ${result.toolCalls.map { it.name }}")

                trace.llmResponse(turnId, turnNumber, result)
                if (result.content != null || result.reasoning != null) {
                    services.historyManager.addItem(ResponseItem.Message(
                        kind = MessageKind.ASSISTANT_TEXT,
                        content = result.content.orEmpty(),
                        reasoning = result.reasoning,
                    ))
                }

                val arbitration = turnPolicyEngine.arbitrateToolCalls(result.toolCalls)
                trace.arbitrationDecision(
                        turnId = turnId,
                        turnNumber = turnNumber,
                        decision = buildArbitrationDecision(result.toolCalls, arbitration)
                )
                emitArbitrationWarnings(turnNumber, arbitration)

                trace.llmReasoning(turnId, turnNumber, reasoning.toString())

                return PlanningPhaseOutput(turnResult = result, arbitration = arbitration)
        }

        private suspend fun emitArbitrationWarnings(
                turnNumber: Int,
                arbitration: ToolArbitrationResult
        ) {
                val droppedCount = arbitration.droppedToolCalls.size
                if (droppedCount > 0) {
                        val keptNames = arbitration.selectedToolCalls.map { it.name }
                        val droppedNames = arbitration.droppedToolCalls.map { it.name }
                        Log.w(
                                TAG,
                                "Turn $turnNumber: Kept $keptNames, dropped $droppedNames"
                        )
                        eventDispatcher.status(
                                "⚠️ Dropped $droppedCount tool call(s): $droppedNames"
                        )
                }
                if (arbitration.hasCompletionTool && arbitration.hasScreenAction) {
                        Log.w(
                                TAG,
                                "Turn $turnNumber: complete_task returned with screen action; completion deferred"
                        )
                        eventDispatcher.status(
                                "⚠️ Completion returned with screen action; executing action first"
                        )
                }
        }

        private fun buildArbitrationDecision(
                originalCalls: List<ToolCallRequest>,
                arbitration: ToolArbitrationResult
        ): ArbitrationDecision {
                val originalNameCounts = originalCalls.groupingBy { it.name }.eachCount()
                val selectedToolIds = arbitration.selectedToolCalls.map { it.id }.toSet()
                val dropped =
                        originalCalls.filterNot { it.id in selectedToolIds }.map { call ->
                                val reason =
                                        when {
                                                call.name == ToolName.CompleteTask.raw &&
                                                        arbitration.hasScreenAction ->
                                                        DropReason.COMPLETE_TASK_DEFERRED
                                                (originalNameCounts[call.name] ?: 0) > 1 ->
                                                        DropReason.DUPLICATE_TOOL
                                                arbitration.selectedToolCalls.isNotEmpty() ->
                                                        DropReason.MAX_TOOLS_EXCEEDED
                                                else -> DropReason.POLICY_REJECTION
                                        }
                                DroppedToolCall(toolName = call.name, reason = reason)
                        }

                return ArbitrationDecision(
                        selectedTools = arbitration.selectedToolCalls,
                        droppedToolCalls = dropped,
                        selectedToolCount = arbitration.selectedToolCalls.size,
                        originalToolCount = originalCalls.size
                )
        }
}
