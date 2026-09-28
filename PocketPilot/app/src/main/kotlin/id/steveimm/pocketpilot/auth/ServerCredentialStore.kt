package id.steveimm.pocketpilot.auth

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import id.steveimm.pocketpilot.llm.ServerBaseUrlValidator
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import org.json.JSONObject

class ServerCredentialStore(
    private val context: Context,
    private val prefsProvider: (Context) -> SharedPreferences = ::encryptedPreferences,
) {
    private val prefs by lazy { prefsProvider(context) }
    private val generations = ConcurrentHashMap<String, AtomicLong>()

    fun apiKey(baseUrl: String): String {
        val url = ServerBaseUrlValidator.validate(baseUrl).getOrThrow()
        val key = storageKey(url)
        if (prefs.contains(key)) return prefs.getString(key, "").orEmpty()
        val settings = context.getSharedPreferences("agent_prefs", Context.MODE_PRIVATE)
        val legacyUrl = settings.getString("other_base_url", "").orEmpty()
        if (ServerBaseUrlValidator.validate(legacyUrl).getOrNull() != url) return ""
        val legacy = prefs.getString("OTHER", null) ?: return ""
        val value = runCatching {
            JSONObject(legacy).takeIf { it.optString("type") == "api_key" }?.optString("key").orEmpty()
        }.getOrDefault("")
        prefs.edit().putString(key, value).remove("OTHER").apply()
        return value
    }

    fun setApiKey(baseUrl: String, value: String) {
        val url = ServerBaseUrlValidator.validate(baseUrl).getOrThrow()
        prefs.edit().putString(storageKey(url), value.trim()).apply()
        generations.computeIfAbsent(url) { AtomicLong() }.incrementAndGet()
    }

    fun generation(baseUrl: String): Long = generations[ServerBaseUrlValidator.validate(baseUrl).getOrThrow()]?.get() ?: 0L

    private fun storageKey(url: String): String = "server:" +
        MessageDigest.getInstance("SHA-256").digest(url.toByteArray()).joinToString("") { "%02x".format(it) }

    companion object {
        private fun encryptedPreferences(context: Context): SharedPreferences {
            val key = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
            return EncryptedSharedPreferences.create(
                context, "auth_store", key,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }
    }
}
