package id.steveimm.pocketpilot.llm

import id.steveimm.pocketpilot.auth.AuthStore
import id.steveimm.pocketpilot.auth.MissingCredential
import android.util.Log
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext

/** Creates [LLMClient] instances from model names using the [ModelCatalog]. */
class LLMClientFactory(
        private val catalog: ModelCatalog,
        private val authStore: AuthStore?,
        private val baseUrlOverrides: Map<LLMProvider, String> = emptyMap(),
        private val clientOverride: LLMClient? = null,
) {
    companion object {
        private const val TAG = "LLMClientFactory"

        /** Create a factory that always returns the given [client] regardless of model name. Useful for unit tests that inject a
         * mock/fake LLM. */
        fun forTest(catalog: ModelCatalog, client: LLMClient): LLMClientFactory =
                LLMClientFactory(catalog, authStore = null, clientOverride = client)
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

        val entry = catalog.resolve(modelName)
        val currentGeneration = if (entry.provider != LLMProvider.LOCAL_LFM) {
            authStore?.generation(entry.provider) ?: 0L
        } else 0L
        val existing = clientCache[modelName]
        if (existing != null && existing.generation == currentGeneration) {
            return@synchronized existing.client
        }

        val client = build(entry)
        ownedClients += client
        clientCache[modelName] = Entry(currentGeneration, client)
        Log.d(TAG, "Created ${client.javaClass.simpleName} for '$modelName' (provider=${entry.provider}, gen=$currentGeneration)")
        client
    }

    internal fun owns(client: LLMClient): Boolean = synchronized(lock) {
        ownedClients.any { it === client }
    }

    private fun build(entry: ModelEntry): LLMClient {
        val store = authStore
                ?: throw IllegalStateException(
                        "LLMClientFactory has no AuthStore — test-only factory cannot build clients for model '${entry.name}'."
                )
        val baseUrl = baseUrlOverrides[entry.provider] ?: entry.effectiveBaseUrl
        return when (entry.provider) {
            LLMProvider.OPENAI_API ->
                    when (entry.api) {
                        ApiType.RESPONSE ->
                                OpenAIResponseClient(store.requireApiKey(LLMProvider.OPENAI_API), baseUrl)
                        ApiType.CHAT ->
                                ChatCompletionClient(store.requireApiKey(LLMProvider.OPENAI_API), baseUrl)
                    }
            LLMProvider.OPENAI_CODEX ->
                    CodexResponseClient(
                            headerSupplier = { store.codexHeaders(LLMProvider.OPENAI_CODEX) }
                    )
            LLMProvider.OPENROUTER ->
                    ChatCompletionClient(store.requireApiKey(LLMProvider.OPENROUTER), baseUrl)
            LLMProvider.OTHER -> {
                // Hard-require a non-blank baseUrl at this boundary.
                val otherBaseUrl = entry.baseUrl
                if (otherBaseUrl.isNullOrBlank()) {
                    throw MissingCredential(LLMProvider.OTHER)
                }
                ChatCompletionClient(store.requireApiKey(LLMProvider.OTHER), otherBaseUrl, allowHttp = true)
            }
            LLMProvider.LOCAL_LFM ->
                    throw IllegalStateException(
                            "LLMClientFactory does not build LFMLLMClient; use LFMLLMClient(context) directly."
                    )
        }
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
