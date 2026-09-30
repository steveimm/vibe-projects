package id.steveimm.pocketpilot.llm

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import org.junit.Test
import java.time.Duration
import java.util.concurrent.TimeUnit

class ModelCancellationTest {
    private val finished = """data: {"id":"r","choices":[{"index":0,"delta":{"content":"Done"},"finish_reason":"stop"}]}""" + "\n\ndata: [DONE]\n\n"

    @Test
    fun `stop before headers releases the request and permits another task`() = runBlocking<Unit> {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
            val client = ChatCompletionClient(server.url("/v1").toString())
            try {
                val pending = launch(Dispatchers.IO) { client.chatWithToolsStreaming("help", emptyList(), emptyList(), "local").toList() }
                checkNotNull(server.takeRequest(2, TimeUnit.SECONDS))
                withTimeout(1_000) { pending.cancelAndJoin() }
                server.enqueue(MockResponse().setHeader("Content-Type", "text/event-stream").setBody(finished))
                val events = withTimeout(3_000) { client.chatWithToolsStreaming("help", emptyList(), emptyList(), "local").toList() }
                assertThat(events.filterIsInstance<LLMStreamEvent.Completed>()).hasSize(1)
            } finally { client.cleanup() }
        }
    }

    @Test
    fun `stop while a stream is stalled preserves received output and returns promptly`() = runBlocking<Unit> {
        java.net.ServerSocket(0).use { server ->
            val serving = launch(Dispatchers.IO) {
                server.accept().use { socket ->
                    val input = socket.getInputStream()
                    val header = StringBuilder()
                    while (!header.endsWith("\r\n\r\n")) {
                        val byte = input.read()
                        check(byte != -1) { "Request closed before headers" }
                        header.append(byte.toChar())
                    }
                    val length = Regex("(?i)Content-Length: (\\d+)").find(header)?.groupValues?.get(1)?.toInt() ?: 0
                    input.readNBytes(length)
                    val prefix = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\n" +
                        "data: {\"id\":\"r\",\"choices\":[{\"index\":0,\"delta\":{\"reasoning\":\"Checking\"}}]}\n\n"
                    socket.getOutputStream().apply { write(prefix.toByteArray()); flush() }
                    while (input.read() != -1) Unit
                }
            }
            val client = ChatCompletionClient("http://127.0.0.1:${server.localPort}/v1")
            val received = CompletableDeferred<Unit>()
            val events = mutableListOf<LLMStreamEvent>()
            try {
                val pending = launch(Dispatchers.IO) {
                    client.chatWithToolsStreaming("help", emptyList(), emptyList(), "local").collect {
                        events.add(it)
                        if (it is LLMStreamEvent.ReasoningDelta) received.complete(Unit)
                    }
                }
                withTimeout(3_000) { received.await() }
                withTimeout(1_000) { pending.cancelAndJoin() }
                assertThat(events.filterIsInstance<LLMStreamEvent.ReasoningDelta>().single().delta).isEqualTo("Checking")
                assertThat(events.filterIsInstance<LLMStreamEvent.Completed>()).isEmpty()
            } finally {
                client.cleanup()
                withTimeout(1_000) { serving.join() }
            }
        }
    }

    @Test
    fun `silent server fails within the configured idle timeout without repeating the request`() = runBlocking<Unit> {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
            val client = ChatCompletionClient(server.url("/v1").toString(), idleTimeout = Duration.ofMillis(250))
            try {
                val events = withTimeout(2_000) { client.chatWithToolsStreaming("help", emptyList(), emptyList(), "local").toList() }
                assertThat(events.filterIsInstance<LLMStreamEvent.Failed>().single().error).contains("stopped responding")
                assertThat(server.requestCount).isEqualTo(1)
                assertThat(events.filterIsInstance<LLMStreamEvent.Completed>()).isEmpty()
            } finally { client.cleanup() }
        }
    }

    @Test
    fun `server errors have one retry rather than nested SDK retries`() = runBlocking<Unit> {
        MockWebServer().use { server ->
            repeat(2) { server.enqueue(MockResponse().setResponseCode(503).setBody("""{"error":{"message":"offline"}}""")) }
            val client = ChatCompletionClient(server.url("/v1").toString())
            try {
                val events = withTimeout(4_000) { client.chatWithToolsStreaming("help", emptyList(), emptyList(), "local").toList() }
                assertThat(events.filterIsInstance<LLMStreamEvent.Failed>()).hasSize(1)
                assertThat(server.requestCount).isEqualTo(2)
            } finally { client.cleanup() }
        }
    }

    @Test
    fun `nonstreaming requests also stop before headers`() = runBlocking<Unit> {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
            val client = ChatCompletionClient(server.url("/v1").toString())
            try {
                val pending = launch(Dispatchers.IO) { client.chatWithTools("help", emptyList(), emptyList(), "local", null) }
                checkNotNull(server.takeRequest(2, TimeUnit.SECONDS))
                withTimeout(1_000) { pending.cancelAndJoin() }
            } finally { client.cleanup() }
        }
    }
    @Test
    fun `takeover interrupts planning and resume permits a fresh request`() = runBlocking<Unit> {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
            val client = ChatCompletionClient(server.url("/v1").toString())
            try {
                val result = CompletableDeferred<Throwable?>()
                val pending = launch(Dispatchers.IO) {
                    result.complete(runCatching {
                        client.chatWithToolsStreaming("help", emptyList(), emptyList(), "local").toList()
                    }.exceptionOrNull())
                }
                checkNotNull(server.takeRequest(2, TimeUnit.SECONDS))
                client.setPaused(true)
                assertThat(withTimeout(1_000) { result.await() }).isInstanceOf(ModelRequestPausedException::class.java)
                pending.join()
                client.setPaused(false)
                server.enqueue(MockResponse().setHeader("Content-Type", "text/event-stream").setBody(finished))
                val events = withTimeout(3_000) { client.chatWithToolsStreaming("help", emptyList(), emptyList(), "local").toList() }
                assertThat(events.filterIsInstance<LLMStreamEvent.Completed>()).hasSize(1)
            } finally { client.cleanup() }
        }
    }

    @Test
    fun `heartbeat bytes without model progress do not keep a task thinking forever`() = runBlocking<Unit> {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setHeader("Content-Type", "text/event-stream")
                .setBody(": heartbeat\n\n".repeat(100)).throttleBody(13, 20, TimeUnit.MILLISECONDS))
            val client = ChatCompletionClient(server.url("/v1").toString(), idleTimeout = Duration.ofMillis(250))
            try {
                val events = withTimeout(2_000) { client.chatWithToolsStreaming("help", emptyList(), emptyList(), "local").toList() }
                assertThat(events.filterIsInstance<LLMStreamEvent.Failed>().single().error).contains("stopped responding")
                assertThat(server.requestCount).isEqualTo(1)
            } finally { client.cleanup() }
        }
    }

}
