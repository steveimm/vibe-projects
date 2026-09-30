package id.steveimm.pocketpilot.llm

import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withTimeoutOrNull
import java.net.SocketTimeoutException
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

internal data class ModelServerResponse(val statusCode: Int, val body: String)

internal object ModelServerHttp {
    private val client = OkHttpClient.Builder()
        .followRedirects(false)
        .followSslRedirects(false)
        .retryOnConnectionFailure(false)
        .connectTimeout(2, TimeUnit.SECONDS)
        .readTimeout(3, TimeUnit.SECONDS)
        .build()

    suspend fun getModels(baseUrl: String, apiKey: String, timeoutSeconds: Long = 3): ModelServerResponse = withContext(Dispatchers.IO) {
        val url = ServerBaseUrlValidator.validate(baseUrl).getOrThrow()
        val request = Request.Builder().url("$url/models").header("Accept", "application/json").apply {
            if (apiKey.isNotBlank()) header("Authorization", "Bearer $apiKey")
        }.build()
        val call = client.newCall(request)
        call.timeout().timeout(timeoutSeconds, TimeUnit.SECONDS)
        return@withContext withTimeoutOrNull(timeoutSeconds * 1_000) { suspendCancellableCoroutine { continuation ->
            continuation.invokeOnCancellation { call.cancel() }
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    if (continuation.isActive) continuation.resumeWithException(e)
                }

                override fun onResponse(call: Call, response: Response) {
                    response.use {
                        try {
                            val body = if (response.isSuccessful) response.body.string() else ""
                            if (continuation.isActive) continuation.resume(ModelServerResponse(response.code, body))
                        } catch (e: IOException) {
                            if (continuation.isActive) continuation.resumeWithException(e)
                        }
                    }
                }
            })
        } } ?: throw SocketTimeoutException("Connection timed out")
    }
}
