package id.steveimm.pocketpilot.llm

import id.steveimm.pocketpilot.auth.AuthStore
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertThrows
import org.junit.Test
import java.util.concurrent.TimeUnit

class CustomServerHttpTest {

    @Test(timeout = 30_000)
    fun `custom HTTP server handles discovery chat and streaming with its own credentials`() = runBlocking {
        MockWebServer().use { server ->
            server.start()
            val baseUrl = OtherBaseUrlValidator.validate(server.url("/v1").toString()).getOrThrow()
            server.enqueue(MockResponse().setBody("""{"data":[{"id":"local-model"}]}"""))
            val models = ModelDiscovery.discover(LLMProvider.OTHER, baseUrl, "local-test-key")
            assertThat(models.single().entry.baseUrl).isEqualTo(baseUrl)
            assertThat(models.single().entry.modelId).isEqualTo("local-model")

            val catalog = ModelCatalog.fromJson(
                """{"other-custom":{"display_name":"Local","provider":"OTHER","api":"chat",
                    "model_id":"local-model","base_url":"$baseUrl"}}"""
            )
            val authStore = mockk<AuthStore> {
                every { generation(LLMProvider.OTHER) } returns 0L
                every { requireApiKey(LLMProvider.OTHER) } returns "local-test-key"
            }
            val factory = LLMClientFactory(catalog, authStore)
            try {
                val client = factory.create("other-custom")
                server.enqueue(MockResponse().setHeader("Content-Type", "application/json").setBody(
                    """{"id":"local-1","object":"chat.completion","created":1,"model":"local-model",
                        "choices":[{"index":0,"message":{"role":"assistant","content":"Local reply"},
                        "finish_reason":"stop"}]}"""
                ))
                val reply = client.chatWithTools("local private prompt", emptyList(), emptyList(), "local-model")
                assertThat(reply.textContent).isEqualTo("Local reply")

                server.enqueue(MockResponse().setHeader("Content-Type", "text/event-stream").setBody(
                    """
                    data: {"id":"local-2","object":"chat.completion.chunk","created":1,"model":"local-model","choices":[{"index":0,"delta":{"role":"assistant","content":"Streamed reply"},"finish_reason":null}]}

                    data: {"id":"local-2","object":"chat.completion.chunk","created":1,"model":"local-model","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

                    data: [DONE]


                    """.trimIndent()
                ))
                val events = client.chatWithToolsStreaming("local private prompt", emptyList(), emptyList(), "local-model").toList()
                assertThat(events.filterIsInstance<LLMStreamEvent.TextDelta>().joinToString("") { it.delta })
                    .isEqualTo("Streamed reply")
                assertThat(events.last()).isEqualTo(LLMStreamEvent.Completed)

                for (path in listOf("/v1/models", "/v1/chat/completions", "/v1/chat/completions")) {
                    val request = requireNotNull(server.takeRequest(2, TimeUnit.SECONDS))
                    assertThat(request.path).isEqualTo(path)
                    assertThat(request.getHeader("Authorization")).isEqualTo("Bearer local-test-key")
                    if (path.endsWith("completions")) {
                        assertThat(request.body.readUtf8()).contains("local private prompt")
                    }
                }
                assertThat(server.requestCount).isEqualTo(3)
            } finally {
                factory.cleanupAll()
            }
        }
    }

    @Test
    fun `HTTP opt in requires an explicit valid custom URL`() {
        for (url in listOf(null, "", "ftp://server/v1", "http://user:secret@server/v1", "http://server/v1?key=secret")) {
            assertThrows(IllegalArgumentException::class.java) {
                ChatCompletionClient("local", url, allowHttp = true)
            }
        }
    }
}
