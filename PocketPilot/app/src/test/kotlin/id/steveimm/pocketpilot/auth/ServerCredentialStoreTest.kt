package id.steveimm.pocketpilot.auth

import android.content.Context
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import org.junit.Test

class ServerCredentialStoreTest {
    @Test
    fun `legacy custom key migrates only to its original endpoint`() {
        val secure = FakeSharedPreferences()
        secure.edit().putString("OTHER", """{"type":"api_key","key":"private-token"}""").apply()
        secure.edit().putString("OPENAI_API", """{"type":"api_key","key":"cloud-token"}""").apply()
        val settings = FakeSharedPreferences()
        settings.edit().putString("other_base_url", "http://server-a:8000/v1").apply()
        val context = mockk<Context> { every { getSharedPreferences("agent_prefs", any()) } returns settings }
        val store = ServerCredentialStore(context, prefsProvider = { secure })
        assertThat(store.apiKey("http://server-b:8000/v1")).isEmpty()
        assertThat(store.apiKey("http://server-a:8000/v1")).isEqualTo("private-token")
        assertThat(secure.contains("OTHER")).isFalse()
        store.setApiKey("http://server-a:8000/v1", "")
        assertThat(store.apiKey("http://server-a:8000/v1")).isEmpty()
        assertThat(store.apiKey("http://server-b:8000/v1")).isEmpty()
    }

    @Test
    fun `optional keys are scoped to the normalized endpoint`() {
        val secure = FakeSharedPreferences()
        val settings = FakeSharedPreferences()
        val context = mockk<Context> { every { getSharedPreferences("agent_prefs", any()) } returns settings }
        val store = ServerCredentialStore(context, prefsProvider = { secure })
        store.setApiKey("http://server-a:8000/v1/chat/completions", "alpha")
        store.setApiKey("http://server-b:8000/v1", "beta")
        assertThat(store.apiKey("http://server-a:8000/v1/")).isEqualTo("alpha")
        assertThat(store.apiKey("http://server-b:8000/v1")).isEqualTo("beta")
        assertThat(store.generation("http://server-a:8000/v1")).isEqualTo(1)
    }
}
