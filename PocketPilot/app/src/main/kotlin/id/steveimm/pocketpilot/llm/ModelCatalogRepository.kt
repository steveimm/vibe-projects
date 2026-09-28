package id.steveimm.pocketpilot.llm

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class ModelCatalogRepository(
    private val discoveryCache: ModelDiscoveryCache,
    private val discover: suspend (String, String) -> List<ModelEntry> = ModelDiscovery::discover,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    suspend fun refresh(baseUrl: String, apiKey: String = ""): List<ModelEntry> = withContext(Dispatchers.IO) {
        val url = ServerBaseUrlValidator.validate(baseUrl).getOrThrow()
        val models = discover(url, apiKey)
        discoveryCache.write(url, clock(), models)
        models
    }

    fun forServer(baseUrl: String, selectedId: String): ModelCatalog {
        val entries = discoveryCache.read(baseUrl)?.entries.orEmpty().toMutableList()
        val modelId = ModelIdValidator.validate(selectedId).getOrNull()
        if (modelId != null && entries.none { it.modelId == modelId }) entries += ModelEntry(name = modelId)
        return ModelCatalog.fromEntries(entries)
    }
}

object ModelCatalogRepositoryHolder {
    @Volatile private var instance: ModelCatalogRepository? = null

    fun get(context: Context): ModelCatalogRepository = instance ?: synchronized(this) {
        instance ?: ModelCatalogRepository(
            ModelDiscoveryCache(context.applicationContext),
        ).also { instance = it }
    }
}
