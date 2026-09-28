package id.steveimm.pocketpilot.app

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.auth.AuthCredential
import id.steveimm.pocketpilot.auth.AuthStore
import id.steveimm.pocketpilot.auth.OAuthTokens
import id.steveimm.pocketpilot.auth.OpenAiSignInResult
import id.steveimm.pocketpilot.llm.LLMProvider
import id.steveimm.pocketpilot.ui.settings.OpenAiAuthUiState
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Test

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class SettingsAuthControllerTest {
    private val tokens = OAuthTokens("access", "refresh", 123L, "person@example.com", "id-token")

    @Test
    fun `loading credentials suspends without blocking and restores the signed in account`() = runTest {
        val store = mockk<AuthStore>()
        val credential = CompletableDeferred<AuthCredential.OAuth>()
        coEvery { store.get(LLMProvider.OPENAI_CODEX) } coAnswers { credential.await() }
        val controller = SettingsAuthController(
            authStore = store,
            scope = backgroundScope,
            launchBrowser = {},
            onSignedIn = {},
            ioDispatcher = StandardTestDispatcher(testScheduler),
        )

        controller.load()
        runCurrent()
        assertThat(controller.state).isEqualTo(OpenAiAuthUiState.SignedOut)

        credential.complete(AuthCredential.OAuth("access", "refresh", 123L, "person@example.com", idToken = null))
        runCurrent()
        assertThat(controller.state).isEqualTo(OpenAiAuthUiState.SignedIn("person@example.com"))
    }

    @Test
    fun `successful sign in stores OAuth credentials before selecting the backend`() = runTest {
        val store = mockk<AuthStore>(relaxed = true)
        val events = mutableListOf<String>()
        coEvery { store.set(LLMProvider.OPENAI_CODEX, any()) } coAnswers { events += "stored" }
        val callback = CompletableDeferred<Unit>()
        val controller = SettingsAuthController(
            authStore = store,
            scope = backgroundScope,
            launchBrowser = { events += it },
            onSignedIn = { events += "backend" },
            signIn = { launchBrowser, onCallbackReceived ->
                launchBrowser("authorization-page")
                callback.await()
                onCallbackReceived()
                OpenAiSignInResult.Success(tokens)
            },
            ioDispatcher = StandardTestDispatcher(testScheduler),
        )

        controller.startSignIn()
        controller.startSignIn()
        runCurrent()
        assertThat(controller.state).isEqualTo(OpenAiAuthUiState.InProgress)
        assertThat(events).containsExactly("authorization-page")

        callback.complete(Unit)
        runCurrent()

        assertThat(controller.state).isEqualTo(OpenAiAuthUiState.SignedIn(tokens.email))
        assertThat(events).containsExactly("authorization-page", "stored", "backend").inOrder()
        coVerify(exactly = 1) {
            store.set(LLMProvider.OPENAI_CODEX, AuthCredential.OAuth("access", "refresh", 123L, tokens.email, "id-token"))
        }
    }

    @Test
    fun `starting sign in cancels an unfinished credential read`() = runTest {
        val store = mockk<AuthStore>(relaxed = true)
        val credential = CompletableDeferred<AuthCredential?>()
        coEvery { store.get(LLMProvider.OPENAI_CODEX) } coAnswers { credential.await() }
        val controller = SettingsAuthController(
            authStore = store,
            scope = backgroundScope,
            launchBrowser = {},
            onSignedIn = {},
            signIn = { _, _ -> OpenAiSignInResult.Success(tokens) },
            ioDispatcher = StandardTestDispatcher(testScheduler),
        )

        controller.load()
        runCurrent()
        controller.startSignIn()
        runCurrent()
        credential.complete(null)
        runCurrent()

        assertThat(controller.state).isEqualTo(OpenAiAuthUiState.SignedIn(tokens.email))
    }

    @Test
    fun `sign out cancels a pending sign in and clears only the OAuth credential`() = runTest {
        val store = mockk<AuthStore>(relaxed = true)
        val callback = CompletableDeferred<Unit>()
        val controller = SettingsAuthController(
            authStore = store,
            scope = backgroundScope,
            launchBrowser = {},
            onSignedIn = { error("Cancelled sign in must not select a backend") },
            signIn = { _, _ ->
                callback.await()
                OpenAiSignInResult.Success(tokens)
            },
            ioDispatcher = StandardTestDispatcher(testScheduler),
        )

        controller.startSignIn()
        runCurrent()
        controller.signOut()
        callback.complete(Unit)
        runCurrent()

        assertThat(controller.state).isEqualTo(OpenAiAuthUiState.SignedOut)
        coVerify(exactly = 0) { store.set(any(), any()) }
        coVerify(exactly = 1) { store.clear(LLMProvider.OPENAI_CODEX) }
        coVerify(exactly = 0) { store.clear(LLMProvider.OPENAI_API) }
        coVerify(exactly = 0) { store.clear(LLMProvider.OTHER) }
    }

    @Test
    fun `credential read failure is shown in auth state`() = runTest {
        val store = mockk<AuthStore>()
        coEvery { store.get(LLMProvider.OPENAI_CODEX) } throws IllegalStateException("Secure storage unavailable")
        val controller = SettingsAuthController(
            authStore = store,
            scope = backgroundScope,
            launchBrowser = {},
            onSignedIn = {},
            ioDispatcher = StandardTestDispatcher(testScheduler),
        )

        controller.load()
        runCurrent()

        assertThat(controller.state).isEqualTo(OpenAiAuthUiState.Error("Secure storage unavailable"))
    }

    @Test
    fun `credential write failure keeps the backend unchanged and shows an error`() = runTest {
        val store = mockk<AuthStore>()
        coEvery { store.set(LLMProvider.OPENAI_CODEX, any()) } throws IllegalStateException("Could not save credentials")
        val controller = SettingsAuthController(
            authStore = store,
            scope = backgroundScope,
            launchBrowser = {},
            onSignedIn = { error("Failed credential writes must not select the backend") },
            signIn = { _, _ -> OpenAiSignInResult.Success(tokens) },
            ioDispatcher = StandardTestDispatcher(testScheduler),
        )

        controller.startSignIn()
        runCurrent()

        assertThat(controller.state).isEqualTo(OpenAiAuthUiState.Error("Could not save credentials"))
    }

    @Test
    fun `sign out failure is shown instead of claiming the credential was removed`() = runTest {
        val store = mockk<AuthStore>()
        coEvery { store.clear(LLMProvider.OPENAI_CODEX) } throws IllegalStateException("Could not remove credentials")
        val controller = SettingsAuthController(
            authStore = store,
            scope = backgroundScope,
            launchBrowser = {},
            onSignedIn = {},
            ioDispatcher = StandardTestDispatcher(testScheduler),
        )

        controller.signOut()
        runCurrent()

        assertThat(controller.state).isEqualTo(OpenAiAuthUiState.Error("Could not remove credentials"))
    }

}
