package id.steveimm.pocketpilot.llm

import com.google.common.truth.Truth.assertThat
import org.junit.Assert.assertThrows
import org.junit.Test

class ReleaseTransportPolicyTest {

    @Test
    fun `cloud clients still reject HTTP in release builds`() {
        assertThrows(IllegalArgumentException::class.java) {
            ChatCompletionClient("cloud-key", "http://cloud.example/v1")
        }
        assertThrows(IllegalArgumentException::class.java) {
            OpenAIResponseClient("cloud-key", "http://cloud.example/v1")
        }
        assertThat(InsecureSslConfig.trustManager).isNull()
        assertThat(InsecureSslConfig.sslSocketFactory).isNull()
    }
}
