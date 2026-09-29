package id.steveimm.pocketpilot.llm

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertThrows
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Before
import org.junit.Test

class ModelDiscoveryTest {

    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun `Metadata-rich fixture parses name + context_length + image modality + tool support`() {
        val body = """
            {"data":[
              {
                "id":"anthropic/claude-opus-4.7",
                "name":"Anthropic Claude Opus 4.7",
                "context_length":200000,
                "created":1700000000,
                "architecture":{"input_modalities":["text","image"],"modality":"text->text"},
                "supported_parameters":["temperature","tools","tool_choice"]
              }
            ]}
        """.trimIndent()

        val entries = ModelDiscovery.parse(body)

        assertThat(entries).hasSize(1)
        val e = entries.single()
        assertThat(e.modelId).isEqualTo("anthropic/claude-opus-4.7")
        assertThat(e.displayName).isEqualTo("Anthropic Claude Opus 4.7")
        assertThat(e.contextWindow).isEqualTo(200000)
        assertThat(entries.single().created).isEqualTo(1700000000L)
    }

    @Test
    fun `Novita-style fixture parses display_name + context_size + endpoints`() {
        val body = """
            {"data":[
              {
                "id":"zai-org/autoglm-phone-9b-multilingual",
                "display_name":"AutoGLM Phone 9B",
                "context_size":131072,
                "model_type":"chat",
                "endpoints":["chat/completions"]
              }
            ]}
        """.trimIndent()

        val entries = ModelDiscovery.parse(body)
        assertThat(entries).hasSize(1)
        val e = entries.single()
        assertThat(e.displayName).isEqualTo("AutoGLM Phone 9B")
        assertThat(e.contextWindow).isEqualTo(131072)
        assertThat(e.modelId).isEqualTo("zai-org/autoglm-phone-9b-multilingual")
    }

    @Test
    fun `OpenAI-bare fixture falls back to id and defaults`() {
        val body = """
            {"data":[
              {"id":"gpt-4o-mini","object":"model","created":1721000000,"owned_by":"openai"}
            ]}
        """.trimIndent()

        val entries = ModelDiscovery.parse(body)
        assertThat(entries).hasSize(1)
        val e = entries.single()
        assertThat(e.modelId).isEqualTo("gpt-4o-mini")
        assertThat(e.displayName).isEqualTo("gpt-4o-mini")
        assertThat(e.contextWindow).isEqualTo(128_000)
    }

    @Test
    fun `entry without tools in supported_parameters is dropped`() {
        val body = """
            {"data":[
              {"id":"chat/no-tools","supported_parameters":["temperature"]},
              {"id":"chat/with-tools","supported_parameters":["temperature","tools"]}
            ]}
        """.trimIndent()

        val ids = ModelDiscovery.parse(body)
            .map { it.modelId }
        assertThat(ids).containsExactly("chat/with-tools")
    }

    @Test
    fun `entry without supported_parameters field is accepted (upstream lacks declaration)`() {
        val body = """{"data":[{"id":"chat/unknown"}]}"""
        val entries = ModelDiscovery.parse(body)
        assertThat(entries.map { it.modelId }).containsExactly("chat/unknown")
    }

    @Test
    fun `Embedding model dropped by id substring`() {
        val body = """
            {"data":[
              {"id":"openai/text-embedding-3-small","supported_parameters":["tools"]},
              {"id":"openai/gpt-5","supported_parameters":["tools"]}
            ]}
        """.trimIndent()
        val ids = ModelDiscovery.parse(body)
            .map { it.modelId }
        assertThat(ids).containsExactly("openai/gpt-5")
    }

    @Test
    fun `Novita embedding model dropped by model_type`() {
        val body = """
            {"data":[
              {"id":"baai/bge-large","model_type":"embedding"},
              {"id":"qwen/chat-7b","model_type":"chat"}
            ]}
        """.trimIndent()
        val ids = ModelDiscovery.parse(body)
            .map { it.modelId }
        assertThat(ids).containsExactly("qwen/chat-7b")
    }

    @Test
    fun `OpenAI-bare embedding model dropped by id substring fallback`() {
        val body = """
            {"data":[
              {"id":"text-embedding-3-small","object":"model"},
              {"id":"gpt-4o","object":"model"}
            ]}
        """.trimIndent()
        val ids = ModelDiscovery.parse(body)
            .map { it.modelId }
        assertThat(ids).containsExactly("gpt-4o")
    }

    @Test
    fun `discovered name is the exact server model ID`() {
        val body = """{"data":[{"id":"vendor/x"}]}"""
        val e = ModelDiscovery.parse(body).single()
        assertThat(e.name).isEqualTo("vendor/x")
    }

    @Test
    fun `modelId rejected if it contains whitespace or starts with colon or slash`() {
        val body = """
            {"data":[
              {"id":"with space"},
              {"id":":colon-start"},
              {"id":"/slash-start"},
              {"id":"vendor/ok-model"}
            ]}
        """.trimIndent()
        val ids = ModelDiscovery.parse(body)
            .map { it.modelId }
        assertThat(ids).containsExactly("vendor/ok-model")
    }

    @Test
    fun `displayName strips control characters and caps at 80`() {
        val longName = "A".repeat(120)
        val body = """
            {"data":[
              {"id":"vendor/a","name":"HelloWorld"},
              {"id":"vendor/b","name":"$longName"}
            ]}
        """.trimIndent()
        val entries = ModelDiscovery.parse(body)
            .associate { it.modelId to it.displayName }
        assertThat(entries["vendor/a"]).isEqualTo("HelloWorld")
        assertThat(entries["vendor/b"]?.length).isEqualTo(80)
    }

    @Test
    fun `discover hits baseUrl slash models with bearer auth`() = runTest {
        server.enqueue(
            MockResponse().setResponseCode(200).setBody(
                """{"data":[{"id":"vendor/x"}]}"""
            )
        )
        val base = server.url("/v1").toString().trimEnd('/')
        val out = ModelDiscovery.discover(base, "sk-test")
        val req = server.takeRequest()
        assertThat(req.path).isEqualTo("/v1/models")
        assertThat(req.getHeader("Authorization")).isEqualTo("Bearer sk-test")
        assertThat(out.single().modelId).isEqualTo("vendor/x")
    }

    @Test
    fun `non-2xx error message contains host only, never URL secrets (Codex r2)`() {
        // The validator would normally block user-info / query / fragment base URLs (covered by ServerBaseUrlValidatorTest).
        server.enqueue(MockResponse().setResponseCode(503).setBody("upstream is down"))

        val sentinel = "SUPERSECRET-do-not-leak"
        val base = server.url("/v1/$sentinel").toString().trimEnd('/')
        val expectedHost = server.url("/").host

        val error = assertThrows(java.io.IOException::class.java) {
            kotlinx.coroutines.runBlocking {
                ModelDiscovery.discover(base, "sk-test")
            }
        }
        val msg = error.message.orEmpty()

        assertThat(msg).doesNotContain(sentinel)
        assertThat(msg).doesNotContain("/v1/$sentinel")
        // Host (or a host-only identifier) IS allowed — the user needs SOME
        // anchor to know which endpoint failed.
        assertThat(msg).contains(expectedHost)
        // Status code should be present so the user has a clue.
        assertThat(msg).contains("503")
    }

    companion object {
        private const val BASE = "https://api.example.com/v1"
    }
}
