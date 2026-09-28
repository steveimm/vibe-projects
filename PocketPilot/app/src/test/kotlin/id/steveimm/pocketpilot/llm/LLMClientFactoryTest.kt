package id.steveimm.pocketpilot.llm

import android.content.Context
import com.google.common.truth.Truth.assertThat
import com.openai.client.OpenAIClient
import id.steveimm.pocketpilot.auth.FakeSharedPreferences
import id.steveimm.pocketpilot.auth.ServerCredentialStore
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertThrows
import org.junit.Test

class LLMClientFactoryTest {
    private val endpoint = "http://localhost:8000/v1"
    private val catalog = ModelCatalog.fromEntries(listOf(ModelEntry("model-a"), ModelEntry("model-b")))

    private fun store(): ServerCredentialStore {
        val preferences = FakeSharedPreferences()
        val context = mockk<Context> { every { getSharedPreferences("agent_prefs", any()) } returns preferences }
        return ServerCredentialStore(context, prefsProvider = { preferences })
    }

    private fun replaceSdk(client: LLMClient): OpenAIClient {
        val sdk = mockk<OpenAIClient>(relaxed = true)
        client.javaClass.getDeclaredField("client").apply { isAccessible = true }.set(client, sdk)
        return sdk
    }

    @Test
    fun `missing endpoint cannot fall back to an SDK default server`() {
        val factory = LLMClientFactory(catalog, null)
        assertThrows(IllegalArgumentException::class.java) { factory.create("model-a") }
    }

    @Test
    fun `unknown models cannot fall back to another catalog entry`() {
        val factory = LLMClientFactory(catalog, null, endpoint)
        assertThrows(IllegalArgumentException::class.java) { factory.create("unknown") }
    }

    @Test
    fun `keyless clients are reused until the configured key changes`() = runBlocking<Unit> {
        val store = store()
        val factory = LLMClientFactory(catalog, store, endpoint)
        val old = factory.create("model-a")
        val oldSdk = replaceSdk(old)
        assertThat(factory.create("model-a")).isSameInstanceAs(old)
        store.setApiKey(endpoint, "new-key")
        val current = factory.create("model-a")
        val currentSdk = replaceSdk(current)
        assertThat(current).isNotSameInstanceAs(old)
        verify(exactly = 0) { oldSdk.close() }
        factory.cleanupAll()
        factory.cleanupAll()
        verify(exactly = 1) { oldSdk.close() }
        verify(exactly = 1) { currentSdk.close() }
        assertThrows(IllegalStateException::class.java) { factory.create("model-a") }
    }

    @Test
    fun `teardown attempts current and retired clients when one close fails`() = runBlocking<Unit> {
        val store = store()
        val factory = LLMClientFactory(catalog, store, endpoint)
        val oldSdk = replaceSdk(factory.create("model-a"))
        every { oldSdk.close() } throws IllegalStateException("close failed")
        store.setApiKey(endpoint, "new-key")
        val currentSdk = replaceSdk(factory.create("model-a"))
        val otherSdk = replaceSdk(factory.create("model-b"))
        val error = runCatching { factory.cleanupAll() }.exceptionOrNull()
        assertThat(generateSequence(error) { it.cause }.lastOrNull()?.message).isEqualTo("close failed")
        verify(exactly = 1) { oldSdk.close() }
        verify(exactly = 1) { currentSdk.close() }
        verify(exactly = 1) { otherSdk.close() }
    }
}
