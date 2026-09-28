package id.steveimm.pocketpilot.session

import android.os.Looper
import id.steveimm.pocketpilot.auth.ServerCredentialStore
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.ModelCatalog
import id.steveimm.pocketpilot.llm.ModelCatalogRepository
import id.steveimm.pocketpilot.llm.ModelIdValidator
import id.steveimm.pocketpilot.llm.ServerBaseUrlValidator
import id.steveimm.pocketpilot.protocol.SessionConfig

internal data class SessionLlmBootstrap(
    val modelCatalog: ModelCatalog,
    val llmClientFactory: LLMClientFactory,
    val llmClient: LLMClient,
)

internal object SessionLlmBootstrapper {
    fun create(config: SessionConfig, catalogRepository: ModelCatalogRepository, credentialStore: ServerCredentialStore?): SessionLlmBootstrap {
        val mainLooper = Looper.getMainLooper()
        check(mainLooper == null || Looper.myLooper() != mainLooper) { "Create model clients off the main thread" }
        val url = ServerBaseUrlValidator.validate(config.llm.baseUrl).getOrThrow()
        val model = ModelIdValidator.validate(config.mainModel).getOrThrow()
        val catalog = catalogRepository.forServer(url, model)
        val factory = LLMClientFactory(catalog, credentialStore, url)
        return SessionLlmBootstrap(catalog, factory, factory.create(model))
    }
}
