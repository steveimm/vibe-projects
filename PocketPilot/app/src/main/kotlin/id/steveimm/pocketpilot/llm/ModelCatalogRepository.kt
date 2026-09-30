package id.steveimm.pocketpilot.llm

import android.content.Context
import android.util.Log
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class ServerConnectionResult(val statusCode: Int, val models: List<ModelEntry>)

class ModelCatalogRepository(
    private val discoveryCache: ModelDiscoveryCache,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    suspend fun testConnection(baseUrl: String, apiKey: String = ""): ServerConnectionResult = withContext(Dispatchers.IO) {
        val url = ServerBaseUrlValidator.validate(baseUrl).getOrThrow()
        val response = ModelServerHttp.getModels(url, apiKey)
        val models = if (response.statusCode in 200..299) ModelDiscovery.parse(response.body) else emptyList()
        if (response.statusCode in 200..299) {
            try { discoveryCache.write(url, clock(), models) }
            catch (e: IOException) { Log.w("ModelCatalog", "Could not cache model list", e) }
        }
        ServerConnectionResult(response.statusCode, models)
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
