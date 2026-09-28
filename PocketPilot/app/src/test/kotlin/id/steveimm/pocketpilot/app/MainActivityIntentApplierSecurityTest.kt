package id.steveimm.pocketpilot.app

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.auth.ServerCredentialStore
import id.steveimm.pocketpilot.protocol.ApprovalMode
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.test.runTest
import org.junit.Test

class MainActivityIntentApplierSecurityTest {
    private val settings = AppSettingsState(mockk(relaxed = true))
    private val credentials = mockk<ServerCredentialStore>(relaxed = true)

    private suspend fun apply(payload: MainActivityIntentPayload, debug: Boolean) = applyIntentPayloadToSettings(
        payload, settings, credentials, debug,
        currentPendingTraceEnabled = false, currentPendingTraceRunId = null,
        currentPendingExcludedTools = emptySet(), currentPendingApprovalMode = null,
        currentPendingEvalTurnBudget = null, log = {},
    )

    @Test
    fun `release intents cannot replace the server credentials or approval policy`() = runTest {
        val result = apply(MainActivityIntentPayload(
            serverBaseUrl = "http://untrusted:8000/v1", serverModelId = "injected", serverApiKey = "secret",
            approvalMode = ApprovalMode.AUTO_APPROVE, traceEnabled = true,
        ), debug = false)
        assertThat(settings.serverBaseUrl).isEmpty()
        assertThat(result.pendingApprovalMode).isNull()
        assertThat(result.pendingTraceEnabled).isFalse()
        verify(exactly = 0) { credentials.setApiKey(any(), any()) }
    }

    @Test
    fun `debug setup accepts a keyless endpoint and normalizes full completion URLs`() = runTest {
        apply(MainActivityIntentPayload(serverBaseUrl = "http://local:8000/v1/chat/completions", serverModelId = "model"), true)
        assertThat(settings.serverBaseUrl).isEqualTo("http://local:8000/v1")
        assertThat(settings.serverModelId).isEqualTo("model")
        verify(exactly = 0) { credentials.setApiKey(any(), any()) }
    }

    @Test
    fun `invalid URLs are rejected before any credential write`() = runTest {
        val result = runCatching { apply(MainActivityIntentPayload(
            serverBaseUrl = "http://user:password@local:8000/v1", serverModelId = "model", serverApiKey = "secret",
        ), true) }
        assertThat(result.isFailure).isTrue()
        assertThat(settings.serverBaseUrl).isEmpty()
        verify(exactly = 0) { credentials.setApiKey(any(), any()) }
    }
}
