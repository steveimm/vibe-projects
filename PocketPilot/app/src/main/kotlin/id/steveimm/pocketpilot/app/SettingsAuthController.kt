package id.steveimm.pocketpilot.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import id.steveimm.pocketpilot.auth.AuthCredential
import id.steveimm.pocketpilot.auth.AuthStore
import id.steveimm.pocketpilot.auth.OpenAiSignInResult
import id.steveimm.pocketpilot.auth.openAiSignIn
import id.steveimm.pocketpilot.llm.LLMProvider
import id.steveimm.pocketpilot.ui.settings.OpenAiAuthUiState
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal class SettingsAuthController(
    private val authStore: AuthStore,
    private val scope: CoroutineScope,
    private val launchBrowser: suspend (String) -> Unit,
    private val onSignedIn: () -> Unit,
    private val signIn: suspend (suspend (String) -> Unit, () -> Unit) -> OpenAiSignInResult = ::openAiSignIn,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    var state by mutableStateOf<OpenAiAuthUiState>(OpenAiAuthUiState.SignedOut)
        private set
    private var operation: Job? = null

    fun load() {
        if (operation?.isActive == true) return
        operation = launchOperation {
            val credential = withContext(ioDispatcher) { authStore.get(LLMProvider.OPENAI_CODEX) }
            state = if (credential is AuthCredential.OAuth) {
                OpenAiAuthUiState.SignedIn(credential.email)
            } else {
                OpenAiAuthUiState.SignedOut
            }
        }
    }

    fun startSignIn() {
        if (state == OpenAiAuthUiState.InProgress || state == OpenAiAuthUiState.Finishing) return
        operation?.cancel()
        state = OpenAiAuthUiState.InProgress
        operation = launchOperation {
            when (val result = signIn(launchBrowser) { state = OpenAiAuthUiState.Finishing }) {
                is OpenAiSignInResult.Success -> {
                    val tokens = result.tokens
                    withContext(ioDispatcher) {
                        authStore.set(
                            LLMProvider.OPENAI_CODEX,
                            AuthCredential.OAuth(
                                accessToken = tokens.accessToken,
                                refreshToken = tokens.refreshToken,
                                expiresAt = tokens.expiresAt,
                                email = tokens.email,
                                idToken = tokens.idToken,
                            ),
                        )
                    }
                    onSignedIn()
                    state = OpenAiAuthUiState.SignedIn(tokens.email)
                }
                is OpenAiSignInResult.Error -> state = OpenAiAuthUiState.Error(result.message)
            }
        }
    }

    fun cancelSignIn() {
        operation?.cancel()
        operation = null
        state = OpenAiAuthUiState.SignedOut
    }

    fun signOut() {
        cancelSignIn()
        operation = launchOperation {
            withContext(ioDispatcher) { authStore.clear(LLMProvider.OPENAI_CODEX) }
        }
    }

    private fun launchOperation(block: suspend () -> Unit): Job = scope.launch {
        try {
            block()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            coroutineContext.ensureActive()
            state = OpenAiAuthUiState.Error(e.message ?: "Unable to access sign-in credentials.")
        }
    }

}
