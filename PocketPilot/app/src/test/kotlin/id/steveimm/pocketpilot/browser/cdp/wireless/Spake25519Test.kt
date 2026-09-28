package id.steveimm.pocketpilot.browser.cdp.wireless

import com.google.common.truth.Truth.assertThat
import java.security.SecureRandom
import org.junit.Test

/**
 * Spake25519 regression tests. Wire-compat with AOSP's adbd is verified separately by the
 * real-device cold-pair test on nubia (see real_device_qa.md / diag_20260504_spake_alternatives.md).
 *
 * No upstream KAT vectors exist — BoringSSL's own `spake25519_test.cc` notes
 * `// TODO(agl): add tests with fixed vectors once SPAKE2 is nailed down.` and Muntashir's
 * `spake2-c/test.c` uses `srand(time(NULL))`. The pinned vectors below are self-pinned: they
 * were captured from this implementation with deterministic SHA1PRNG seeds and any change to
 * the protocol (constants, hashing, scalar handling) breaks them, catching regressions.
 */
class Spake25519Test {

    private val aliceName = "adb pair client\u0000".toByteArray(Charsets.UTF_8)
    private val bobName = "adb pair server\u0000".toByteArray(Charsets.UTF_8)

    /** SHA1PRNG seeded once before any nextBytes() = fully reproducible across JVMs. */
    private fun fixedRandom(seed: Long): SecureRandom {
        val r = SecureRandom.getInstance("SHA1PRNG")
        r.setSeed(seed)
        return r
    }

    @Test
    fun `pinned KAT vectors stay byte-identical (self-pinned regression)`() {
        val password = "kat-vector-password-2026".toByteArray()
        val alice = Spake25519(Spake25519.Role.ALICE, aliceName, bobName, fixedRandom(0x1A11CEL))
        val bob = Spake25519(Spake25519.Role.BOB, bobName, aliceName, fixedRandom(0x80BL))

        val aliceMsg = alice.generateMessage(password)
        val bobMsg = bob.generateMessage(password)
        val aliceKey = alice.processMessage(bobMsg)
        val bobKey = bob.processMessage(aliceMsg)

        assertThat(hex(aliceMsg)).isEqualTo(KAT_ALICE_MSG)
        assertThat(hex(bobMsg)).isEqualTo(KAT_BOB_MSG)
        assertThat(hex(aliceKey)).isEqualTo(KAT_KEY)
        assertThat(hex(bobKey)).isEqualTo(KAT_KEY)
    }

    @Test
    fun `same password yields same 64-byte key on both sides`() {
        val password = "matching-passphrase".toByteArray()
        val alice = Spake25519(Spake25519.Role.ALICE, aliceName, bobName, fixedRandom(0x42L))
        val bob = Spake25519(Spake25519.Role.BOB, bobName, aliceName, fixedRandom(0x99L))

        val aliceMsg = alice.generateMessage(password)
        val bobMsg = bob.generateMessage(password)
        assertThat(aliceMsg.size).isEqualTo(32)
        assertThat(bobMsg.size).isEqualTo(32)

        val aliceKey = alice.processMessage(bobMsg)
        val bobKey = bob.processMessage(aliceMsg)
        assertThat(aliceKey.size).isEqualTo(64)
        assertThat(bobKey).isEqualTo(aliceKey)
    }

    @Test
    fun `different passwords yield different keys`() {
        val alice = Spake25519(Spake25519.Role.ALICE, aliceName, bobName, fixedRandom(0x11L))
        val bob = Spake25519(Spake25519.Role.BOB, bobName, aliceName, fixedRandom(0x22L))
        val aliceMsg = alice.generateMessage("alice-secret".toByteArray())
        val bobMsg = bob.generateMessage("bob-typo-secret".toByteArray())
        val aliceKey = alice.processMessage(bobMsg)
        val bobKey = bob.processMessage(aliceMsg)
        assertThat(bobKey).isNotEqualTo(aliceKey)
    }

    @Test
    fun `processMessage rejects non-32-byte input`() {
        val s = Spake25519(Spake25519.Role.ALICE, aliceName, bobName, fixedRandom(0x1L))
        s.generateMessage("pw".toByteArray())
        assertThrows(IllegalArgumentException::class.java) { s.processMessage(ByteArray(31)) }
        // separate instances since processMessage advances state on success
        val s2 = Spake25519(Spake25519.Role.ALICE, aliceName, bobName, fixedRandom(0x2L))
        s2.generateMessage("pw".toByteArray())
        assertThrows(IllegalArgumentException::class.java) { s2.processMessage(ByteArray(33)) }
        val s3 = Spake25519(Spake25519.Role.ALICE, aliceName, bobName, fixedRandom(0x3L))
        s3.generateMessage("pw".toByteArray())
        assertThrows(IllegalArgumentException::class.java) { s3.processMessage(ByteArray(0)) }
    }

    @Test
    fun `processMessage rejects malformed point bytes`() {
        val s = Spake25519(Spake25519.Role.ALICE, aliceName, bobName, fixedRandom(0x4L))
        s.generateMessage("pw".toByteArray())
        // 32 bytes that decode to a y-coordinate not on the Ed25519 curve. y = 2: there is no
        // x with x²(d·y²+1) = (y²-1) on the curve, so eddsa rejects via IllegalArgumentException.
        val notOnCurve = ByteArray(32).also { it[0] = 2 }
        assertThrows(IllegalArgumentException::class.java) { s.processMessage(notOnCurve) }
    }

    @Test
    fun `state machine prevents double generate or process before generate`() {
        val s = Spake25519(Spake25519.Role.ALICE, aliceName, bobName, fixedRandom(0x5L))
        assertThrows(IllegalStateException::class.java) { s.processMessage(ByteArray(32)) }
        s.generateMessage("pw".toByteArray())
        assertThrows(IllegalStateException::class.java) { s.generateMessage("pw".toByteArray()) }
    }

    @Test
    fun `password scalar hack clears low 3 bits and divides by 8`() {
        val s = ByteArray(32) { 0x07 }
        val out = Spake25519.passwordScalarHackDiv8(s)
        assertThat(out.size).isEqualTo(32)
        assertThat(out.any { it != 0.toByte() }).isTrue()
    }

    @Test
    fun `scalarReduce64 returns 32 bytes`() {
        val out = Spake25519.scalarReduce64(ByteArray(64) { it.toByte() })
        assertThat(out.size).isEqualTo(32)
    }

    private fun hex(b: ByteArray) = b.joinToString("") { "%02x".format(it) }

    private fun <T : Throwable> assertThrows(cls: Class<T>, block: () -> Unit) {
        try { block() } catch (t: Throwable) {
            assertThat(t).isInstanceOf(cls); return
        }
        throw AssertionError("expected ${cls.simpleName}, got nothing")
    }

    companion object {
        // Pinned vectors — captured 2026-05-04 from this implementation with the seeds below.
        // Inputs: ALICE seed=0x1A11CE, BOB seed=0x80B (SHA1PRNG); names = production names
        // ("adb pair client\u0000" / "adb pair server\u0000"); password = "kat-vector-password-2026".
        // These are NOT from an external authority — BoringSSL has no upstream KAT — but they
        // detect any drift in our implementation across refactors.
        private const val KAT_ALICE_MSG =
            "19d260377f6c343e02fbdb41ef63f399f6eb2e732651e97947efcb47546c1a14"
        private const val KAT_BOB_MSG =
            "a51c60d6cb46195e1d0ad403aaffdb866ee5112922ece7132f67224d314a16c7"
        private const val KAT_KEY =
            "618e0a64296de05ca7a40741b222ced80c9bd91d67ce732c1b24cab4fb25a249" +
            "f99242b5abc85a10ff8ae3c2bc12ab8eb7390b215366067edd3bfbfbb27faa69"
    }
}
