package ai.closepaw.llm

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class OtherBaseUrlValidatorTest {

    @Test
    fun `accepts HTTP custom servers on loopback LAN and hostnames`() {
        val cases = listOf(
            "http://localhost",
            "http://127.0.0.1",
            "http://10.0.2.2",
            "http://192.168.1.10:11434/v1",
            "http://10.10.1.2:1234/v1",
            "http://model-server.local:8080/v1",
            "http://[::1]:8080/v1",
            "http://api.example.com/v1",
        )
        for (input in cases) {
            val result = OtherBaseUrlValidator.validate(input)
            assertThat(result.getOrThrow()).isEqualTo(input)
        }
    }

    @Test
    fun `accepts HTTPS custom servers`() {
        val result = OtherBaseUrlValidator.validate("https://api.example.com/v1")
        assertThat(result.isSuccess).isTrue()
        assertThat(result.getOrThrow()).isEqualTo("https://api.example.com/v1")
    }

    @Test
    fun `normalizes HTTP server URL without changing scheme or port`() {
        val result = OtherBaseUrlValidator.validate("  http://192.168.1.10:11434/v1/  ")
        assertThat(result.getOrThrow()).isEqualTo("http://192.168.1.10:11434/v1")
    }

    // ── scheme / host validation ─────────────────────────────────────────

    @Test
    fun `rejects ftp and other non-http schemes`() {
        val result = OtherBaseUrlValidator.validate("ftp://example.com/")
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).hasMessageThat().contains("http")
    }

    @Test
    fun `rejects empty input`() {
        val result = OtherBaseUrlValidator.validate("")
        assertThat(result.isFailure).isTrue()
    }

    @Test
    fun `rejects whitespace-only input`() {
        val result = OtherBaseUrlValidator.validate("   ")
        assertThat(result.isFailure).isTrue()
    }

    @Test
    fun `rejects empty host`() {
        val result = OtherBaseUrlValidator.validate("https:///v1")
        assertThat(result.isFailure).isTrue()
        assertThat(result.exceptionOrNull()).hasMessageThat().contains("host")
    }

    // ── normalization ────────────────────────────────────────────────────

    @Test
    fun `trims trailing slash`() {
        val result = OtherBaseUrlValidator.validate("https://api.example.com/v1/")
        assertThat(result.isSuccess).isTrue()
        assertThat(result.getOrThrow()).isEqualTo("https://api.example.com/v1")
    }

    @Test
    fun `trims surrounding whitespace`() {
        val result = OtherBaseUrlValidator.validate("  https://api.example.com/v1  ")
        assertThat(result.isSuccess).isTrue()
        assertThat(result.getOrThrow()).isEqualTo("https://api.example.com/v1")
    }

    // ── reject sensitive URL segments (Codex review HIGH #2) ─────────────

    @Test
    fun `rejects user-info in URL and message does not echo the secret`() {
        val result = OtherBaseUrlValidator.validate(
            "https://eve:supersecret@api.example.com/v1",
        )
        assertThat(result.isFailure).isTrue()
        val msg = result.exceptionOrNull()?.message.orEmpty()
        // The actual user-info from the input must not appear in the error,
        // but the error may name the rejected element ("credentials").
        assertThat(msg).doesNotContain("supersecret")
        assertThat(msg).doesNotContain("eve")
        assertThat(msg).contains("credentials")
    }

    @Test
    fun `rejects query string and message does not echo the secret`() {
        val result = OtherBaseUrlValidator.validate(
            "https://api.example.com/v1?api_key=supersecret",
        )
        assertThat(result.isFailure).isTrue()
        val msg = result.exceptionOrNull()?.message.orEmpty()
        assertThat(msg).doesNotContain("supersecret")
        assertThat(msg).doesNotContain("api_key")
        assertThat(msg).contains("query")
    }

    @Test
    fun `rejects fragment and message does not echo the secret`() {
        val result = OtherBaseUrlValidator.validate(
            "https://api.example.com/v1#supersecret",
        )
        assertThat(result.isFailure).isTrue()
        val msg = result.exceptionOrNull()?.message.orEmpty()
        assertThat(msg).doesNotContain("supersecret")
        assertThat(msg).contains("fragment")
    }
}
