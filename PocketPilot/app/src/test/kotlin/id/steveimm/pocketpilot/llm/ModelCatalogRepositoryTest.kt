package id.steveimm.pocketpilot.llm

import android.content.Context
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.InterruptedIOException
import java.util.concurrent.TimeUnit

class ModelCatalogRepositoryTest {
    @get:Rule val temporary = TemporaryFolder()
    private fun cache(): ModelDiscoveryCache = ModelDiscoveryCache(mockk<Context> { every { filesDir } returns temporary.root })

    @Test
    fun `manual model ID works without discovery or a bundled catalog`() {
        val repository = ModelCatalogRepository(cache())
        assertThat(repository.forServer("http://local:8000/v1", "custom-model").resolve("custom-model").modelId)
            .isEqualTo("custom-model")
    }

    @Test
    fun `test accepts completion URL without a key and caches advertised models by server`() = runBlocking<Unit> {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setBody("""{"data":[{"id":"local-model","context_length":4096}]}"""))
            val repository = ModelCatalogRepository(cache())
            val base = server.url("/v1").toString()
            val result = repository.testConnection("$base/chat/completions")
            val request = server.takeRequest()
            assertThat(request.path).isEqualTo("/v1/models")
            assertThat(request.getHeader("Authorization")).isNull()
            assertThat(result.statusCode).isEqualTo(200)
            assertThat(result.models.single().modelId).isEqualTo("local-model")
            assertThat(repository.forServer(base, "local-model").resolve("local-model").contextWindow).isEqualTo(4096)
            assertThat(repository.forServer(server.url("/other").toString(), "manual").names()).containsExactly("manual")
        }
    }

    @Test
    fun `authenticated rejection preserves the last successful catalog`() = runBlocking<Unit> {
        MockWebServer().use { server ->
            val repository = ModelCatalogRepository(cache())
            val base = server.url("/v1").toString()
            server.enqueue(MockResponse().setBody("""{"data":[{"id":"local-model"}]}"""))
            repository.testConnection(base)
            server.takeRequest()
            server.enqueue(MockResponse().setResponseCode(401).setBody("secret server detail"))
            val result = repository.testConnection(base, "test-key")
            assertThat(server.takeRequest().getHeader("Authorization")).isEqualTo("Bearer test-key")
            assertThat(result.statusCode).isEqualTo(401)
            assertThat(result.models).isEmpty()
            assertThat(result.toString()).doesNotContain("secret")
            assertThat(repository.forServer(base, "").names()).containsExactly("local-model")
        }
    }

    @Test
    fun `redirect does not forward credentials to another server`() = runBlocking<Unit> {
        MockWebServer().use { origin ->
            MockWebServer().use { destination ->
                origin.enqueue(MockResponse().setResponseCode(302).setHeader("Location", destination.url("/models")))
                val result = ModelServerHttp.getModels(origin.url("/v1").toString(), "test-key")
                assertThat(result.statusCode).isEqualTo(302)
                assertThat(destination.requestCount).isEqualTo(0)
            }
        }
    }

    @Test
    fun `missing model route remains an HTTP response rather than an unreachable server`() = runBlocking<Unit> {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setResponseCode(404).setBody("private server details"))
            val result = ModelCatalogRepository(cache()).testConnection(server.url("/v1").toString())
            assertThat(result.statusCode).isEqualTo(404)
            assertThat(result.models).isEmpty()
        }
    }

    @Test
    fun `leaving a pending connection check cancels promptly`() = runBlocking<Unit> {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
            val pending = async(Dispatchers.IO) { ModelServerHttp.getModels(server.url("/v1").toString(), "") }
            assertThat(server.takeRequest(2, TimeUnit.SECONDS)).isNotNull()
            withTimeout(1_000) { pending.cancelAndJoin() }
            assertThat(pending.isCancelled).isTrue()
        }
    }

    @Test
    fun `unresponsive server has a bounded connection check`() {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
            assertThrows(InterruptedIOException::class.java) {
                runBlocking { ModelServerHttp.getModels(server.url("/v1").toString(), "", timeoutSeconds = 1) }
            }
        }
    }
}
