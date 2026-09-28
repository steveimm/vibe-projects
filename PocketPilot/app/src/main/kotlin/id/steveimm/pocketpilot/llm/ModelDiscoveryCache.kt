package id.steveimm.pocketpilot.llm

import android.content.Context
import java.io.File
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class ModelDiscoveryCache(context: Context) {
    private val file = File(context.filesDir, "server_models.json")
    private val lock = Any()
    private val json = Json { ignoreUnknownKeys = true }

    @Serializable
    data class Bucket(val fetchedAt: Long, val entries: List<ModelEntry>)

    fun read(baseUrl: String): Bucket? = synchronized(lock) { readAll()[baseUrl] }

    fun write(baseUrl: String, fetchedAt: Long, models: List<ModelEntry>) = synchronized(lock) {
        val buckets = readAll().toMutableMap().apply { put(baseUrl, Bucket(fetchedAt, models)) }
        file.parentFile?.mkdirs()
        file.writeText(json.encodeToString(buckets))
    }

    private fun readAll(): Map<String, Bucket> = runCatching {
        if (file.exists()) json.decodeFromString<Map<String, Bucket>>(file.readText()) else emptyMap()
    }.getOrDefault(emptyMap())
}
