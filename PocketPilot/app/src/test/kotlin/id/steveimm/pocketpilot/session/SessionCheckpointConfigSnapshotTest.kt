package id.steveimm.pocketpilot.session

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.perception.PerceptionConfig
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
import org.junit.Test

class SessionCheckpointConfigSnapshotTest {
    @Test
    fun `checkpoint retains its server address model and execution configuration`() {
        val config = SessionConfig(
            mainModel = "local/model", llm = SessionLlmConfig("http://server-a:8000/v1"),
            actionDelayMs = 123, approvalMode = ApprovalMode.AUTO_APPROVE,
            perceptionConfig = PerceptionConfig.Hybrid(), platformMode = PlatformMode.VIRTUAL_DISPLAY,
            debugMode = true, traceEnabled = true, traceRunId = "run", excludedTools = setOf("shell"),
        )
        val restored = config.toConfigSnapshot().toSessionConfig()
        assertThat(restored).isEqualTo(config)
    }
}
