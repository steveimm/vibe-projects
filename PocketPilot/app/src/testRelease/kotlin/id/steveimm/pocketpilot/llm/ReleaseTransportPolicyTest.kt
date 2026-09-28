package id.steveimm.pocketpilot.llm

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class ReleaseTransportPolicyTest {
    @Test
    fun `release allows explicit HTTP servers without disabling TLS verification`() {
        assertThat(ServerBaseUrlValidator.validate("http://local:8000/v1").isSuccess).isTrue()
        assertThat(InsecureSslConfig.sslSocketFactory).isNull()
        assertThat(InsecureSslConfig.trustManager).isNull()
    }
}
