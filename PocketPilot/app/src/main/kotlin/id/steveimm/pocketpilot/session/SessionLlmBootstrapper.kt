package id.steveimm.pocketpilot.session

import android.content.Context
import android.os.Looper
import android.util.Log
import id.steveimm.pocketpilot.auth.AuthStore
import id.steveimm.pocketpilot.auth.MissingCredential
import id.steveimm.pocketpilot.llm.LFMLLMClient
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.LLMProvider
import id.steveimm.pocketpilot.llm.LocalLLMConfig
import id.steveimm.pocketpilot.llm.ModelCatalog
import id.steveimm.pocketpilot.llm.ModelCatalogRepository
import id.steveimm.pocketpilot.protocol.LLMBackendType
import id.steveimm.pocketpilot.protocol.SessionConfig

internal data class SessionLlmBootstrap(
        val modelCatalog: ModelCatalog,
        val llmClientFactory: LLMClientFactory,
        val llmClient: LLMClient
)

/** Creates catalog + LLM factory + runtime LLM client for a session. */
internal object SessionLlmBootstrapper {
    private const val TAG = "SessionLlmBootstrap"

    fun create(
            config: SessionConfig,
            catalogRepository: ModelCatalogRepository,
            context: Context,
            authStore: AuthStore?,
            baseUrlOverrides: Map<LLMProvider, String> = emptyMap()
    ): SessionLlmBootstrap {
        requireOffMainThread()
        val backend = config.llm.backendType
        val baseCatalog = catalogRepository.catalog.value

        val modelCatalog = baseCatalog.withBaseUrlOverrides(baseUrlOverrides)
        if (baseUrlOverrides.isNotEmpty()) {
            Log.d(TAG, "Applied provider base URL overrides: $baseUrlOverrides")
        }
        Log.d(TAG, "Loaded ModelCatalog with ${modelCatalog.size} models: ${modelCatalog.names()}")

        val llmClientFactory =
                LLMClientFactory(
                        catalog = modelCatalog,
                        authStore = authStore,
                        baseUrlOverrides = baseUrlOverrides
                )

        val llmClient =
                when (backend) {
                    LLMBackendType.OPENAI -> {
                        ensureRequiredCredentials(config, modelCatalog, authStore)
                        llmClientFactory.create(config.mainModel)
                    }
                    LLMBackendType.LOCAL -> {
                        val localConfig = config.llm.localConfig ?: LocalLLMConfig()
                        LFMLLMClient(context, localConfig)
                    }
                }

        return SessionLlmBootstrap(
                modelCatalog = modelCatalog,
                llmClientFactory = llmClientFactory,
                llmClient = llmClient
        )
    }

    private fun requireOffMainThread() {
        val mainLooper = Looper.getMainLooper() ?: return
        check(Looper.myLooper() != mainLooper) {
            "SessionLlmBootstrapper.create() must not be called on the main thread; " +
                    "catalog snapshot read should run off-main"
        }
    }

    private fun ensureRequiredCredentials(
            config: SessionConfig,
            catalog: ModelCatalog,
            authStore: AuthStore?
    ) {
        if (authStore == null) return
        if (config.mainModel == ModelCatalogRepository.OTHER_CUSTOM_NAME) {
            // Check missing custom-server settings before catalog lookup so the error opens the correct authentication tab.
            if (catalog.resolveOrNull(config.mainModel) == null ||
                !authStore.has(LLMProvider.OTHER)) {
                throw MissingCredential(LLMProvider.OTHER)
            }
            return
        }
        val provider = catalog.resolve(config.mainModel).provider
        if (provider == LLMProvider.LOCAL_LFM) return
        if (!authStore.has(provider)) {
            throw MissingCredential(provider)
        }
    }
}
