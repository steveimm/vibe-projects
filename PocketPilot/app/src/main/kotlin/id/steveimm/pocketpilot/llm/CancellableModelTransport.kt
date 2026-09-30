package id.steveimm.pocketpilot.llm

import com.openai.core.RequestOptions
import com.openai.core.http.Headers
import com.openai.core.http.HttpClient
import com.openai.core.http.HttpRequest
import com.openai.core.http.HttpResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asContextElement
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.Response
import okio.BufferedSink
import java.io.IOException
import java.io.FilterInputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.time.Duration
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.net.SocketTimeoutException

/** Keeps the actual socket cancellable before headers arrive and while an SSE body is read. */
internal class CancellableModelTransport(private val idleTimeout: Duration) : HttpClient {
    class RequestScope {
        private val calls = mutableMapOf<Call, CompletableFuture<HttpResponse>>()
        private var cancelled = false
        @Volatile var paused = false
            private set
        @Synchronized fun register(call: Call, headers: CompletableFuture<HttpResponse>) {
            if (cancelled) { headers.cancel(true); call.cancel() } else calls[call] = headers
        }
        @Synchronized fun release(call: Call) { calls.remove(call) }
        @Synchronized fun cancel(forPause: Boolean = false) {
            paused = paused || forPause
            cancelled = true
            calls.forEach { (call, headers) -> headers.cancel(true); call.cancel() }
            calls.clear()
        }
    }

    private val currentScope = ThreadLocal<RequestScope>()
    private val scopes = ConcurrentHashMap.newKeySet<RequestScope>()
    private val paused = AtomicBoolean(false)

    fun newScope(): RequestScope = RequestScope().also {
        scopes.add(it)
        if (paused.get()) it.cancel(forPause = true)
    }
    fun finish(scope: RequestScope) { scope.cancel(); scopes.remove(scope) }
    fun setPaused(value: Boolean) {
        paused.set(value)
        if (value) scopes.forEach { it.cancel(forPause = true) }
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(Duration.ofSeconds(5).coerceAtMost(idleTimeout))
        .readTimeout(idleTimeout)
        .writeTimeout(Duration.ofSeconds(15).coerceAtMost(idleTimeout))
        .followRedirects(false)
        .followSslRedirects(false)
        .retryOnConnectionFailure(false)
        .apply {
            val factory = InsecureSslConfig.sslSocketFactory
            val trust = InsecureSslConfig.trustManager
            if (factory != null && trust != null) sslSocketFactory(factory, trust)
        }
        .build()

    fun context(scope: RequestScope) = currentScope.asContextElement(scope)

    suspend fun <T> request(block: suspend () -> T): T = coroutineScope {
        val requests = newScope()
        val worker = async(Dispatchers.IO + context(requests)) { block() }
        try { worker.await() } finally { finish(requests) }
    }

    override fun execute(request: HttpRequest, requestOptions: RequestOptions): HttpResponse {
        val scope = currentScope.get()
        val headers = executeAsync(request, requestOptions)
        return try {
            headers.get(idleTimeout.toMillis(), TimeUnit.MILLISECONDS)
        } catch (e: Exception) {
            headers.cancel(true)
            if (scope?.paused == true) throw ModelRequestPausedException()
            if (e is TimeoutException) throw SocketTimeoutException("Model response headers timed out")
            if (e is ExecutionException) throw (e.cause ?: e)
            throw e
        }
    }

    override fun executeAsync(request: HttpRequest, requestOptions: RequestOptions): CompletableFuture<HttpResponse> {
        val call = newCall(request)
        val scope = currentScope.get()
        val future = CompletableFuture<HttpResponse>()
        future.whenComplete { _, _ -> if (future.isCancelled) call.cancel() }
        scope?.register(call, future)
        call.enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                scope?.release(call)
                request.body?.close()
                future.completeExceptionally(e)
            }
            override fun onResponse(call: Call, response: Response) {
                request.body?.close()
                val result = response(response, call, scope)
                if (!future.complete(result)) result.close()
            }
        })
        return future
    }

    private fun newCall(request: HttpRequest): Call {
        val body = request.body?.let { sdkBody -> object : RequestBody() {
            override fun contentType() = sdkBody.contentType()?.toMediaTypeOrNull()
            override fun contentLength() = sdkBody.contentLength()
            override fun writeTo(sink: BufferedSink) { sdkBody.writeTo(sink.outputStream()) }
        } }
        val builder = Request.Builder().url(request.url()).method(request.method.toString(), body)
        request.headers.names().forEach { name -> request.headers.values(name).forEach { builder.addHeader(name, it) } }
        return client.newCall(builder.build())
    }

    private fun response(response: Response, call: Call, scope: RequestScope?): HttpResponse = object : HttpResponse {
        override fun statusCode() = response.code
        override fun headers(): Headers = Headers.builder().putAll(response.headers.toMultimap()).build()
        override fun body() = object : FilterInputStream(response.body.byteStream()) {
            override fun read(): Int = checkPause { super.read() }
            override fun read(bytes: ByteArray, offset: Int, length: Int): Int = checkPause { super.read(bytes, offset, length) }
            private fun <T> checkPause(read: () -> T): T = try { read() } catch (e: IOException) {
                if (scope?.paused == true) throw ModelRequestPausedException()
                throw e
            }
        }
        override fun close() {
            call.cancel()
            response.close()
            scope?.release(call)
        }
    }

    override fun close() {
        client.dispatcher.cancelAll()
        client.dispatcher.executorService.shutdown()
        client.connectionPool.evictAll()
    }
}
