package id.steveimm.pocketpilot.agent

import android.util.Log
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.ModelCatalog

internal data class AgentModelResolution(
        val llmClient: LLMClient,
        val modelId: String,
)

/** Resolves model runtime details for an agent execution. */
internal class AgentModelResolver(
        private val sessionLlmClient: LLMClient,
        private val modelCatalog: ModelCatalog,
        private val llmClientFactory: LLMClientFactory
) {
        companion object {
                private const val TAG = "AgentModelResolver"
        }

        fun resolve(modelName: String): AgentModelResolution {
                val entry = modelCatalog.resolveOrNull(modelName)
                if (entry != null) {
                        val catalogClient =
                                runCatching { llmClientFactory.create(modelName) }
                                        .onFailure { error ->
                                                Log.w(
                                                        TAG,
                                                        "Failed to create catalog client for '$modelName'; using session fallback",
                                                        error
                                                )
                                        }
                                        .getOrNull()
                        if (catalogClient != null) {
                                return AgentModelResolution(
                                        llmClient = catalogClient,
                                        modelId = entry.modelId,
                                )
                        }
                }

                Log.w(
                        TAG,
                        "Model '$modelName' not found in catalog or client unavailable; using session client fallback"
                )
                return AgentModelResolution(
                        llmClient = sessionLlmClient,
                        modelId = modelName,
                )
        }
}
