package id.steveimm.pocketpilot.llm

import id.steveimm.pocketpilot.auth.ServerCredentialStore
import android.util.Log
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext

/** Creates [LLMClient] instances from model names using the [ModelCatalog]. */
class LLMClientFactory(
        private val catalog: ModelCatalog,
        private val credentialStore: ServerCredentialStore?,
        private val baseUrl: String = "",
        private val clientOverride: LLMClient? = null,
) {
    companion object {
        private const val TAG = "LLMClientFactory"

        /** Create a factory that always returns the given [client] regardless of model name. Useful for unit tests that inject a
         * mock/fake LLM. */
        fun forTest(catalog: ModelCatalog, client: LLMClient): LLMClientFactory =
                LLMClientFactory(catalog, credentialStore = null, clientOverride = client)
    }

    private data class Entry(val generation: Long, val client: LLMClient)

    private val lock = Any()
    private val clientCache = mutableMapOf<String, Entry>()
    private val ownedClients = mutableListOf<LLMClient>()
    private var closed = false

    /** Create or reuse a client. Superseded clients remain usable until session teardown. */
    fun create(modelName: String): LLMClient = synchronized(lock) {
        check(!closed) { "LLM client factory is closed" }
        clientOverride?.let { return@synchronized it }

        catalog.resolve(modelName)
        val currentGeneration = credentialStore?.generation(baseUrl) ?: 0L
        val existing = clientCache[modelName]
        if (existing != null && existing.generation == currentGeneration) {
            return@synchronized existing.client
        }

        val client = build()
        ownedClients += client
        clientCache[modelName] = Entry(currentGeneration, client)
        Log.d(TAG, "Created ${client.javaClass.simpleName} for '$modelName' (gen=$currentGeneration)")
        client
    }

    internal fun owns(client: LLMClient): Boolean = synchronized(lock) {
        ownedClients.any { it === client }
    }

    private fun build(): LLMClient {
        val url = ServerBaseUrlValidator.validate(baseUrl).getOrThrow()
        return ChatCompletionClient(baseUrl = url, apiKey = credentialStore?.apiKey(url).orEmpty())
    }

    /** Close current and superseded clients after the session's callers have stopped. */
    suspend fun cleanupAll(): Unit = withContext(NonCancellable) {
        val clients = synchronized(lock) {
            if (closed) return@withContext
            closed = true
            ownedClients.toList().also {
                ownedClients.clear()
                clientCache.clear()
            }
        }
        val failures = mutableListOf<Exception>()
        for (client in clients) {
            try {
                client.cleanup()
            } catch (error: Exception) {
                failures += error
            }
        }
        if (failures.isNotEmpty()) {
            throw IllegalStateException("Failed to clean up ${failures.size} LLM clients", failures.first()).apply {
                failures.drop(1).forEach(::addSuppressed)
            }
        }
    }
}
