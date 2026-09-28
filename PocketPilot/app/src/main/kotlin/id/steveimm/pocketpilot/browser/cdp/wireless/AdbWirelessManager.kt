package id.steveimm.pocketpilot.browser.cdp.wireless

import id.steveimm.pocketpilot.browser.cdp.shizuku.ChromeDevtoolsUserService
import id.steveimm.pocketpilot.browser.cdp.shizuku.IChromeDevtoolsUserService
import android.util.Log
import java.io.IOException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runInterruptible

/** App-side facade for the wireless-ADB management calls exposed by [IChromeDevtoolsUserService]. */
class AdbWirelessManager(
    private val binderProvider: suspend () -> IChromeDevtoolsUserService,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {

    suspend fun currentBssid(): String? = onBinder { it.getCurrentBssid() }

    /** Looks up the current Wi-Fi BSSID then calls `IAdbManager.allowWirelessDebugging(true, bssid)` via the shell-UID service.
     * Wireless ADB is BSSID-scoped on Android 14+, so a missing BSSID (Wi-Fi off, cellular only) is fatal. */
    suspend fun enableWirelessDebugging(): Result<Unit> = runCatching {
        val bssid = currentBssid()
            ?: throw IOException("No Wi-Fi BSSID available; cannot enable wireless ADB")
        val ok = onBinder { it.enableWirelessDebugging(bssid) }
        if (!ok) throw IOException("IAdbManager.allowWirelessDebugging returned false; check logcat")
    }

    /** -1 when wireless ADB is not listening. */
    suspend fun getAdbWirelessPort(): Int = onBinder { it.getAdbWirelessPort() }

    /** Calls `IAdbManager.enablePairingByQrCode(name, psk)` then discovers the listening pair port via `/proc/net/tcp` diff. `psk` is
     * taken as bytes (caller may use a binary PSK) and rendered as the UTF-8 string adb's TLS-PSK pairing accepts. */
    suspend fun openPairPort(name: String, psk: ByteArray): Int {
        require(psk.isNotEmpty()) { "psk must not be empty" }
        val pskStr = String(psk, Charsets.UTF_8)
        val port = onBinder { it.enablePairingByQrCode(name, pskStr) }
        if (port <= 0) throw IOException("pair port did not appear within 5s")
        return port
    }

    suspend fun closePairPort() {
        onBinder { it.disablePairing() }
    }

    /** True iff [pubkeyBase64] (base64 of the 524-byte AOSP `android_pubkey` blob) is present in `/data/misc/adb/adb_keys`. */
    suspend fun isPubkeyAuthorized(pubkeyBase64: String): Boolean =
        pubkeyAuthorizationStatus(pubkeyBase64) == AuthorizationStatus.AUTHORIZED

    /** Tri-state variant of [isPubkeyAuthorized] that distinguishes "adb_keys exists but our key is not in it" from "adb_keys was
     * unreadable to us" (locked OEMs whose shell uid is dropped from the `adb` group). */
    suspend fun pubkeyAuthorizationStatus(pubkeyBase64: String): AuthorizationStatus {
        if (pubkeyBase64.isEmpty()) return AuthorizationStatus.NOT_AUTHORIZED
        val readStatus = onBinder { it.adbKeysReadStatus() }
        return when (readStatus) {
            ChromeDevtoolsUserService.ADB_KEYS_STATUS_READABLE -> {
                val content = onBinder { it.readAdbKeys() }
                when {
                    // adbKeysReadStatus said READABLE but readAdbKeys returned null → race or partial failure between the two calls. Treat
                    // as NOT_AUTHORIZED — safer to re-pair than to short-circuit on uncertain state.
                    content == null -> AuthorizationStatus.NOT_AUTHORIZED
                    content.contains(pubkeyBase64) -> AuthorizationStatus.AUTHORIZED
                    else -> AuthorizationStatus.NOT_AUTHORIZED
                }
            }
            ChromeDevtoolsUserService.ADB_KEYS_STATUS_EACCES -> AuthorizationStatus.UNREADABLE
            // ADB_KEYS_STATUS_MISSING / ADB_KEYS_STATUS_OTHER → adbd has no entries (or we
            // can't reason about its state); cache MUST NOT short-circuit.
            else -> AuthorizationStatus.NOT_AUTHORIZED
        }
    }

    enum class AuthorizationStatus {
        /** `/data/misc/adb/adb_keys` was readable and contained our pubkey. */
        AUTHORIZED,

        /** `/data/misc/adb/adb_keys` was readable but our pubkey was absent. */
        NOT_AUTHORIZED,

        /** `/data/misc/adb/adb_keys` could not be read (typically EACCES on locked OEMs). */
        UNREADABLE,
    }

    /** Removes accumulated `PocketPilot@*` entries from `/data/misc/adb/adb_keys`, retaining exactly one — the line whose pubkey equals
     * [retainPubkeyBase64]. Non-PocketPilot lines pass through unchanged. */
    suspend fun pruneAdbKeys(retainPubkeyBase64: String): Boolean {
        require(retainPubkeyBase64.isNotEmpty()) { "retainPubkeyBase64 must not be empty" }
        val content = onBinder { it.readAdbKeys() } ?: return false
        val maxRepeats = mostFrequentPubkeyCount(content)
        if (maxRepeats > MAX_DUPLICATE_PUBKEY_LINES) {
            Log.w(
                TAG,
                "pruneAdbKeys: skipping write — adb_keys has $maxRepeats copies of a single " +
                    "pubkey (cap $MAX_DUPLICATE_PUBKEY_LINES); investigate pair-once fallback growth",
            )
            return false
        }
        val result = prunePocketPilotEntries(content, retainPubkeyBase64)
        if (!result.foundCurrent) return false
        if (!result.changed) return false
        return onBinder { it.writeAdbKeys(result.content) }
    }

    private suspend inline fun <T> onBinder(crossinline block: (IChromeDevtoolsUserService) -> T): T {
        val binder = binderProvider()
        return try {
            runInterruptible(ioDispatcher) { block(binder) }
        } catch (t: Throwable) {
            Log.w(TAG, "binder call failed: ${t.javaClass.simpleName}: ${t.message}", t)
            throw t
        }
    }

    internal data class PruneResult(
        val content: String,
        val foundCurrent: Boolean,
        val changed: Boolean,
    )

    companion object {
        private const val TAG = "AdbWirelessManager"
        private const val POCKETPILOT_NAME_PREFIX = "PocketPilot@"
        // adbd's auth.cpp tokenizes adb_keys on \s+ (not space-only), so honor tab-separated
        // entries from other writers when matching/preserving lines.
        private val WHITESPACE = Regex("\\s+")
        // Hard ceiling for [pruneAdbKeys] — see KDoc on that function.
        internal const val MAX_DUPLICATE_PUBKEY_LINES = 10

        /** Largest count of any single first-token pubkey across all non-blank lines. Matches adbd's `\s+` tokenization so
         * tab-separated and space-separated entries collide as intended. */
        internal fun mostFrequentPubkeyCount(content: String): Int {
            val counts = HashMap<String, Int>()
            var max = 0
            for (raw in content.split('\n')) {
                val line = raw.trimEnd('\r')
                if (line.isBlank()) continue
                val pubkey = line.split(WHITESPACE, limit = 2)[0]
                val next = (counts[pubkey] ?: 0) + 1
                counts[pubkey] = next
                if (next > max) max = next
            }
            return max
        }

        /** Drop blank lines and any `PocketPilot@*`-named line whose pubkey is not [retainPubkeyBase64]. */
        internal fun prunePocketPilotEntries(
            content: String,
            retainPubkeyBase64: String,
        ): PruneResult {
            val out = StringBuilder()
            var keptCurrent = false
            var foundCurrent = false
            for (raw in content.split('\n')) {
                val line = raw.trimEnd('\r')
                if (line.isBlank()) continue
                val tokens = line.split(WHITESPACE, limit = 2)
                val pubkey = tokens[0]
                val name = if (tokens.size > 1) tokens[1] else ""
                val isPocketPilot = name.startsWith(POCKETPILOT_NAME_PREFIX) || pubkey == retainPubkeyBase64
                if (isPocketPilot) {
                    if (pubkey == retainPubkeyBase64) {
                        foundCurrent = true
                        if (!keptCurrent) {
                            out.append(line).append('\n')
                            keptCurrent = true
                        }
                    }
                } else {
                    out.append(line).append('\n')
                }
            }
            val outStr = out.toString()
            return PruneResult(outStr, foundCurrent, changed = outStr != content)
        }
    }
}
