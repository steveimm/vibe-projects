package id.steveimm.pocketpilot.agent

import id.steveimm.pocketpilot.test.testModelCatalog

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.auth.ServerCredentialStore
import id.steveimm.pocketpilot.llm.LLMClient
import id.steveimm.pocketpilot.llm.LLMClientFactory
import id.steveimm.pocketpilot.llm.LLMStreamEvent
import id.steveimm.pocketpilot.llm.ResponsesResult
import io.mockk.every
import io.mockk.mockk
import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import org.junit.Test

class AgentModelResolverTest {

        @Test
        fun `known catalog model uses factory metadata and client`() {
                val sessionClient = FakeTestLLMClient()
                val catalog =
                        testModelCatalog(
                                """
                {
                  "test-model": {
                    "display_name": "Test Model",
                    "model_id": "provider-model-id",
                    "supports_vision": true
                  }
                }
                """
                        )
                val factory = LLMClientFactory(catalog = catalog, credentialStore = fakeStore(), baseUrl = "http://localhost:8000/v1")
                val resolver = AgentModelResolver(sessionClient, catalog, factory)

                val resolved = resolver.resolve("test-model")

                assertThat(resolved.modelId).isEqualTo("provider-model-id")
                assertThat(resolved.supportsVision).isTrue()
                assertThat(resolved.llmClient).isNotSameInstanceAs(sessionClient)
        }

        @Test
        fun `unknown model falls back to session client`() {
                val sessionClient = FakeTestLLMClient()
                val catalog =
                        testModelCatalog(
                                """
                {
                  "known-model": {
                    "display_name": "Known Model",
                    "model_id": "known-model-id"
                  }
                }
                """
                        )
                val factory = LLMClientFactory(catalog = catalog, credentialStore = fakeStore(), baseUrl = "http://localhost:8000/v1")
                val resolver = AgentModelResolver(sessionClient, catalog, factory)

                val resolved = resolver.resolve("legacy-local-model")

                assertThat(resolved.llmClient).isSameInstanceAs(sessionClient)
                assertThat(resolved.modelId).isEqualTo("legacy-local-model")
                assertThat(resolved.supportsVision).isFalse()
        }

        @Test
        fun `known model falls back to session client when factory cannot build client`() {
                val sessionClient = FakeTestLLMClient()
                val catalog =
                        testModelCatalog(
                                """
                {
                  "known-model": {
                    "display_name": "Known Model",
                    "model_id": "known-model-id",
                    "supports_vision": true
                  }
                }
                """
                        )
                val factory = LLMClientFactory(catalog = catalog, credentialStore = emptyStore(), baseUrl = "http://localhost:8000/v1")
                val resolver = AgentModelResolver(sessionClient, catalog, factory)

                val resolved = resolver.resolve("known-model")

                assertThat(resolved.llmClient).isSameInstanceAs(sessionClient)
                assertThat(resolved.modelId).isEqualTo("known-model")
                assertThat(resolved.supportsVision).isFalse()
        }

        private fun fakeStore(): ServerCredentialStore {
                val store = mockk<ServerCredentialStore>(relaxed = true)
                every { store.generation(any()) } returns 0L
                every { store.apiKey(any()) } returns "test-key"
                return store
        }

        private fun emptyStore(): ServerCredentialStore {
                val store = mockk<ServerCredentialStore>(relaxed = true)
                every { store.generation(any()) } returns 0L
                every { store.apiKey(any()) } throws IllegalStateException("Cannot read server credentials")
                return store
        }
}

private class FakeTestLLMClient : LLMClient() {
        override suspend fun chatWithTools(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String,
        maxOutputTokens: Long?,
        ): ResponsesResult {
                error("Not used in tests")
        }

        override fun chatWithToolsStreaming(
                systemPrompt: String,
                inputItems: List<ResponseInputItem>,
                tools: List<FunctionTool>,
                model: String
        ): Flow<LLMStreamEvent> = emptyFlow()
}
