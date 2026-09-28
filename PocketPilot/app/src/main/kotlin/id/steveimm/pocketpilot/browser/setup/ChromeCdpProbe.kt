package id.steveimm.pocketpilot.browser.setup

import id.steveimm.pocketpilot.browser.cdp.shizuku.DefaultDevtoolsDiagnostics
import id.steveimm.pocketpilot.browser.cdp.shizuku.ShizukuChromeDevtoolsBridge
import java.io.File
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Detects whether Chrome's `chrome_devtools_remote` abstract socket is currently bound. */
class ChromeCdpProbe(
    private val procNetUnix: File = DEFAULT_PROC_NET_UNIX,
    private val shellRunner: ShellRunner? = null,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {

    /** Return Unknown if neither app nor shell can inspect the socket. Otherwise distinguish bound from absent. */
    suspend fun probe(): Result = withContext(ioDispatcher) {
        // Try app-uid first — cheaper, no Shizuku binder roundtrip.
        runCatching { procNetUnix.readText() }
            .getOrNull()
            ?.let { return@withContext parse(it) }

        // App uid was denied (SELinux on locked OEM builds, or some MDM policies). Fall
        // through to shell uid via Shizuku so the same kernel data is reachable.
        val runner = shellRunner ?: return@withContext Result.Unknown
        val shellResult = runCatching {
            runner.run(arrayOf("grep", "-F", GREP_NEEDLE, PROC_NET_UNIX_PATH))
        }.onFailure { if (it is CancellationException) throw it }
            .getOrNull() ?: return@withContext Result.Unknown
        // grep exit codes: 0 = matched, 1 = no match (file readable), 2 = error reading file. Both 0 and 1 prove the file was readable via
        // shell uid; only 2 (or our runner's -1 sentinel for binder/timeout failure) means we genuinely cannot probe.
        when (shellResult.exitCode) {
            0 -> parse(shellResult.stdout)
            1 -> Result.NotBound
            else -> Result.Unknown
        }
    }

    enum class Result { Bound, NotBound, Unknown }

    companion object {
        private const val PROC_NET_UNIX_PATH = "/proc/net/unix"
        private val DEFAULT_PROC_NET_UNIX = File(PROC_NET_UNIX_PATH)
        // Substring needle for grep — the strict token match still happens in DefaultDevtoolsDiagnostics.containsAbstractSocket so
        // `@chrome_devtools_remote_unrelated` would be filtered out even though grep would surface the line.
        internal const val GREP_NEEDLE =
            "@" + ShizukuChromeDevtoolsBridge.CHROME_DEVTOOLS_SOCKET

        /** Token-aware match — delegates to the runtime preflight parser so this probe and the bridge cannot disagree about what counts
         * as the chrome devtools socket. */
        internal fun parse(procNetUnix: String): Result {
            val bound = DefaultDevtoolsDiagnostics.containsAbstractSocket(
                procContent = procNetUnix,
                socketName = ShizukuChromeDevtoolsBridge.CHROME_DEVTOOLS_SOCKET,
            )
            return if (bound) Result.Bound else Result.NotBound
        }
    }
}
