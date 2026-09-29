package id.steveimm.pocketpilot.app

import android.content.Context
import android.content.SharedPreferences
import id.steveimm.pocketpilot.protocol.AppTier
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import io.mockk.unmockkAll
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.After
import org.junit.Before
import org.junit.Test

class AppSettingsStoreTest {
    private lateinit var backing: MutableMap<String, Any?>
    private lateinit var context: Context

    @Before
    fun setUp() {
        backing = mutableMapOf()
        val prefs = fakePrefs(backing)
        context = mockk(relaxed = true) {
            every { getSharedPreferences("agent_prefs", any()) } returns prefs
        }
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    @Test
    fun `server settings start empty with no cloud defaults`() {
        val settings = AppSettingsStore(context).load()
        assertThat(settings.serverBaseUrl).isEmpty()
        assertThat(settings.serverModelId).isEmpty()
    }

    @Test
    fun `existing custom server and discovered model selection migrate`() {
        backing["other_base_url"] = "http://server-a:8000/v1/"
        backing["other_model_id"] = "old-manual"
        backing["model"] = "other:selected-model"
        val settings = AppSettingsStore(context).load()
        assertThat(settings.serverBaseUrl).isEqualTo("http://server-a:8000/v1")
        assertThat(settings.serverModelId).isEqualTo("selected-model")
    }

    @Test
    fun `old cloud selections never become a configured model server`() {
        backing["model"] = "gpt-5.2"
        backing["openai_base_url"] = "https://api.openai.com/v1"
        val settings = AppSettingsStore(context).load()
        assertThat(settings.serverBaseUrl).isEmpty()
        assertThat(settings.serverModelId).isEmpty()
    }

    @Test
    fun `clearing new settings does not restore legacy custom server values`() {
        backing["other_base_url"] = "http://server-a:8000/v1"
        backing["other_model_id"] = "old-model"
        val store = AppSettingsStore(context)
        store.saveServer("", "")
        assertThat(store.load().serverBaseUrl).isEmpty()
        assertThat(store.load().serverModelId).isEmpty()
    }

    @Test
    fun `server state persists both fields without changing unrelated preferences`() {
        val store = AppSettingsStore(context)
        val state = AppSettingsState(store)
        state.load()
        state.updateTraceEnabled(true)
        state.updateServer("http://server-a:8000/v1", "my-model")
        state.load()
        assertThat(state.serverBaseUrl).isEqualTo("http://server-a:8000/v1")
        assertThat(state.serverModelId).isEqualTo("my-model")
        assertThat(state.traceEnabled).isTrue()
    }

    @Test
    fun `unknown platform and retired approval mode fall back safely`() {
        backing["platform_mode"] = "removed"
        backing["approval_mode"] = "ALWAYS_ASK"
        val settings = AppSettingsStore(context).load()
        assertThat(settings.platformMode).isEqualTo(AppSettingsStore.DEFAULT_PLATFORM_MODE)
        assertThat(settings.approvalMode).isEqualTo(AppSettingsStore.DEFAULT_APPROVAL_MODE)
    }

    @Test
    fun `user app overrides default to empty`() {
        assertThat(AppSettingsStore(context).loadUserAppOverrides()).isEmpty()
    }

    @Test
    fun `user app overrides round-trip through store`() = runBlocking {
        val store = AppSettingsStore(context)
        val overrides = mapOf(
            "com.spotify.music" to AppTier.NORMAL,
            "com.evil.app" to AppTier.BLOCKED,
            "com.unknown.app" to AppTier.CAUTIOUS,
        )

        store.saveUserAppOverrides(overrides)

        assertThat(AppSettingsStore(context).loadUserAppOverrides()).isEqualTo(overrides)
    }

    @Test
    fun `saving empty overrides clears the stored value`() = runBlocking {
        val store = AppSettingsStore(context)
        store.saveUserAppOverrides(mapOf("com.spotify.music" to AppTier.NORMAL))
        store.saveUserAppOverrides(emptyMap())

        assertThat(AppSettingsStore(context).loadUserAppOverrides()).isEmpty()
    }

    @Test
    fun `unknown tier strings are dropped silently`() {
        val raw = JSONObject().apply {
            put("com.good.app", "NORMAL")
            put("com.weird.app", "PURPLE")
            put("com.blocked.app", "BLOCKED")
        }.toString()
        backing["user_app_overrides"] = raw

        val loaded = AppSettingsStore(context).loadUserAppOverrides()

        assertThat(loaded).containsExactly(
            "com.good.app", AppTier.NORMAL,
            "com.blocked.app", AppTier.BLOCKED,
        )
    }

    @Test
    fun `malformed JSON falls back to empty map`() {
        backing["user_app_overrides"] = "not a json object"

        assertThat(AppSettingsStore(context).loadUserAppOverrides()).isEmpty()
    }

    private fun fakePrefs(backing: MutableMap<String, Any?>): SharedPreferences {
        val editor = mockk<SharedPreferences.Editor>(relaxed = true)
        every { editor.putString(any(), any()) } answers {
            backing[firstArg()] = secondArg<String?>()
            editor
        }
        every { editor.putBoolean(any(), any()) } answers {
            backing[firstArg()] = secondArg<Boolean>()
            editor
        }
        every { editor.putInt(any(), any()) } answers {
            backing[firstArg()] = secondArg<Int>()
            editor
        }
        every { editor.putStringSet(any(), any()) } answers {
            backing[firstArg()] = secondArg<Set<String>?>()
            editor
        }
        every { editor.remove(any()) } answers {
            backing.remove(firstArg<String>())
            editor
        }

        val prefs = mockk<SharedPreferences>(relaxed = true)
        every { prefs.edit() } returns editor
        every { prefs.getString(any(), any()) } answers {
            backing[firstArg()] as? String ?: secondArg()
        }
        every { prefs.getBoolean(any(), any()) } answers {
            backing[firstArg()] as? Boolean ?: secondArg()
        }
        every { prefs.getInt(any(), any()) } answers {
            backing[firstArg()] as? Int ?: secondArg()
        }
        every { prefs.getStringSet(any(), any()) } answers {
            @Suppress("UNCHECKED_CAST")
            (backing[firstArg()] as? Set<String>) ?: secondArg()
        }
        return prefs
    }
}
