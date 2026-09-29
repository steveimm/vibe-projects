package id.steveimm.pocketpilot.llm

import com.google.common.truth.Truth.assertThat
import com.openai.models.responses.EasyInputMessage
import id.steveimm.pocketpilot.agent.cognition.prompt.PromptBuilder
import id.steveimm.pocketpilot.agent.cognition.prompt.TurnObservation
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.history.MessageKind
import id.steveimm.pocketpilot.history.ResponseItem
import id.steveimm.pocketpilot.history.model.HistoryItemConverter
import id.steveimm.pocketpilot.history.model.PersistedHistoryItem
import id.steveimm.pocketpilot.session.AgentSessionState
import id.steveimm.pocketpilot.trace.LlmInputItemsTraceSerializer
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import com.openai.models.responses.ResponseInputItem
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.json.JSONObject
import org.junit.Test
import java.util.concurrent.TimeUnit

class CustomServerHttpTest {
    private fun message() = ResponseInputItem.ofEasyInputMessage(
        EasyInputMessage.builder().role(EasyInputMessage.Role.USER).content("hello").build(),
    )

    @Test
    fun `keyless server discovery and chat use only the supplied HTTP endpoint`() = runTest {
        MockWebServer().use { server ->
            server.start()
            server.enqueue(MockResponse().setBody("""{"data":[{"id":"local-model"}]}"""))
            val base = server.url("/v1").toString()
            val models = ModelDiscovery.discover(base, "")
            val discovery = server.takeRequest(5, TimeUnit.SECONDS)!!
            assertThat(discovery.path).isEqualTo("/v1/models")
            assertThat(discovery.getHeader("Authorization")).isNull()
            val factory = LLMClientFactory(ModelCatalog.fromEntries(models), null, base)
            try {
                server.enqueue(MockResponse().setBody("""{"id":"answer","object":"chat.completion","created":0,"model":"local-model","choices":[{"index":0,"message":{"role":"assistant","content":"hello"},"finish_reason":"stop"}]}"""))
                factory.create("local-model").chatWithTools("help", listOf(message()), emptyList(), "local-model", null)
                val chat = server.takeRequest(5, TimeUnit.SECONDS)!!
                assertThat(chat.path).isEqualTo("/v1/chat/completions")
                assertThat(chat.getHeader("Authorization")).isNull()
                assertThat(JSONObject(chat.body.readUtf8()).getString("model")).isEqualTo("local-model")
            } finally {
                factory.cleanupAll()
            }
        }
    }

    @Test
    fun `explicit key is sent to the configured endpoint and full completion URLs are accepted`() = runTest {
        MockWebServer().use { server ->
            server.start()
            server.enqueue(MockResponse().setBody("""{"id":"answer","object":"chat.completion","created":0,"model":"local-model","choices":[{"index":0,"message":{"role":"assistant","content":"ok"},"finish_reason":"stop"}]}"""))
            val client = ChatCompletionClient(server.url("/v1/chat/completions").toString(), "server-token")
            try {
                client.chatWithTools("help", listOf(message()), emptyList(), "local-model", null)
                val request = server.takeRequest(5, TimeUnit.SECONDS)!!
                assertThat(request.path).isEqualTo("/v1/chat/completions")
                assertThat(request.getHeader("Authorization")).isEqualTo("Bearer server-token")
            } finally {
                client.cleanup()
            }
        }
    }

    @Test
    fun `native reasoning fields stream separately from the assistant answer`() = runTest {
        MockWebServer().use { server ->
            server.start()
            val client = ChatCompletionClient(server.url("/v1").toString())
            try {
                for (field in listOf("reasoning", "reasoning_content")) {
                    val body = listOf(
                        """data: {"id":"r","choices":[{"index":0,"delta":{"$field":"First "}}]}""",
                        """data: {"id":"r","choices":[{"index":0,"delta":{"$field":"check the screen."}}]}""",
                        """data: {"id":"r","choices":[{"index":0,"delta":{"content":"Done."},"finish_reason":"stop"}]}""",
                        "data: [DONE]",
                    ).joinToString("\n\n", postfix = "\n\n")
                    server.enqueue(MockResponse().setHeader("Content-Type", "text/event-stream").setBody(body))
                    val events = mutableListOf<LLMStreamEvent>()
                    client.chatWithToolsStreaming("help", listOf(message()), emptyList(), "local-model").collect { events += it }
                    assertThat(events.filterIsInstance<LLMStreamEvent.ReasoningDelta>().joinToString("") { it.delta })
                        .isEqualTo("First check the screen.")
                    assertThat(events.filterIsInstance<LLMStreamEvent.TextDelta>().joinToString("") { it.delta }).isEqualTo("Done.")
                }
            } finally {
                client.cleanup()
            }
        }
    }

    @Test
    fun `persisted reasoning travels with the assistant tool call in the next HTTP request`() = runTest {
        MockWebServer().use { server ->
            server.start()
            val client = ChatCompletionClient(server.url("/v1").toString())
            try {
                for (field in listOf("reasoning", "reasoning_content")) {
                    val original = ResponseItem.Message(MessageKind.ASSISTANT_TEXT, "", reasoning = ModelReasoning("Inspect before tapping.", field))
                    val encoded = Json.encodeToString<PersistedHistoryItem>(HistoryItemConverter.toRecord(original))
                    val restored = HistoryItemConverter.fromRecord(Json.decodeFromString<PersistedHistoryItem>(encoded))
                    val history = HistoryManager()
                    history.addItem(restored)
                    history.addItem(ResponseItem.FunctionCall("call1", "open_app", JSONObject("""{"app_name":"Settings"}""")))
                    history.addItem(ResponseItem.FunctionCallOutput("call1", "Settings opened"))
                    val items = PromptBuilder(history, AgentSessionState()).buildInputItems(
                        TurnObservation(null, 0, false, false, null, "Current screen: Settings"),
                    )
                    assertThat(LlmInputItemsTraceSerializer.toJson(items)[0].jsonObject[field]?.jsonPrimitive?.content)
                        .isEqualTo("Inspect before tapping.")
                    server.enqueue(MockResponse().setBody("""{"id":"answer","object":"chat.completion","created":0,"model":"local-model","choices":[{"index":0,"message":{"role":"assistant","content":"Done"},"finish_reason":"stop"}]}"""))
                    client.chatWithTools("help", items, emptyList(), "local-model", null)
                    val request = server.takeRequest(5, TimeUnit.SECONDS)!!
                    val messages = JSONObject(request.body.readUtf8()).getJSONArray("messages")
                    val assistant = messages.getJSONObject(1)
                    assertThat(assistant.getString("role")).isEqualTo("assistant")
                    assertThat(assistant.getString(field)).isEqualTo("Inspect before tapping.")
                    assertThat(assistant.getString("content")).isEmpty()
                    assertThat(assistant.getJSONArray("tool_calls").getJSONObject(0).getString("id")).isEqualTo("call1")
                    assertThat(messages.getJSONObject(2).getString("tool_call_id")).isEqualTo("call1")
                    assertThat((restored as ResponseItem.Message).estimateTokens()).isGreaterThan(4)
                }
            } finally {
                client.cleanup()
            }
        }
    }

    @Test
    fun `a slow collector receives every streaming delta from the configured server`() = runTest {
        MockWebServer().use { server ->
            server.start()
            val body = buildString {
                repeat(200) {
                    append("data: {\"id\":\"stream\",\"object\":\"chat.completion.chunk\",\"created\":0,\"model\":\"local-model\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"x\"}}]}\n\n")
                }
                append("data: {\"id\":\"stream\",\"object\":\"chat.completion.chunk\",\"created\":0,\"model\":\"local-model\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n")
            }
            server.enqueue(MockResponse().setHeader("Content-Type", "text/event-stream").setBody(body))
            val client = ChatCompletionClient(server.url("/v1").toString())
            try {
                val events = mutableListOf<LLMStreamEvent>()
                client.chatWithToolsStreaming("help", listOf(message()), emptyList(), "local-model").collect {
                    delay(1)
                    events += it
                }
                assertThat(events.filterIsInstance<LLMStreamEvent.TextDelta>().joinToString("") { it.delta }).isEqualTo("x".repeat(200))
                assertThat(events.any { it is LLMStreamEvent.Completed }).isTrue()
            } finally {
                client.cleanup()
            }
        }
    }
}
