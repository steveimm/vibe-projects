package id.steveimm.pocketpilot.browser.cdp.shizuku

import android.content.pm.PackageManager
import android.os.SystemClock
import id.steveimm.pocketpilot.platform.ShizukuShell
import java.io.File
import rikka.shizuku.Shizuku

/** Adapter exposing the [ShizukuStatusProvider] surface backed by the real Shizuku binder. */
class ShizukuStatusAdapter : ShizukuStatusProvider {
    /** Shizuku publishes its binder to apps via [rikka.shizuku.ShizukuProvider]'s on-demand broadcast — which can lag a second or two
     * behind app start (especially after `adb install -r` when the prior process death dropped the cached binder). */
    override fun isAvailable(): Boolean = waitFor { Shizuku.pingBinder() }
    override fun hasPermission(): Boolean = runCatching {
        Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
    }.getOrDefault(false)

    private fun waitFor(predicate: () -> Boolean): Boolean {
        val deadline = SystemClock.uptimeMillis() + BINDER_WAIT_MS
        var ok = runCatching { predicate() }.getOrDefault(false)
        while (!ok && SystemClock.uptimeMillis() < deadline) {
            Thread.sleep(BINDER_POLL_MS)
            ok = runCatching { predicate() }.getOrDefault(false)
        }
        return ok
    }

    companion object {
        private const val BINDER_WAIT_MS = 2_000L
        private const val BINDER_POLL_MS = 100L
    }
}

/** Best-effort device-side diagnostics. */
class DefaultDevtoolsDiagnostics(
    private val procNetUnix: File = File("/proc/net/unix"),
    private val chromeRunningProbe: () -> ChromeRunningResult = { ChromeRunningResult.Unknown },
) : DevtoolsDiagnostics {

    override fun isDevtoolsSocketBound(): SocketProbeResult {
        val text = runCatching { procNetUnix.readText() }.getOrNull()
            ?: return SocketProbeResult.Unknown
        return if (containsAbstractSocket(text, ShizukuChromeDevtoolsBridge.CHROME_DEVTOOLS_SOCKET)) {
            SocketProbeResult.Bound
        } else {
            SocketProbeResult.NotBound
        }
    }

    override fun isChromeRunning(): ChromeRunningResult = chromeRunningProbe()

    companion object {
        /** `/proc/net/unix` lines look like: `0000000000000000: 00000003 00000000 00010000 0001 01 1234 @chrome_devtools_remote_5678`
         * Match `@<name>` exactly OR `@<name>_<pid>` (Chrome appends `_<pid>` on some builds). */
        fun containsAbstractSocket(procContent: String, socketName: String): Boolean {
            val needleExact = "@$socketName"
            return procContent.lineSequence().any { line ->
                val token = line.trim().substringAfterLast(' ', "")
                token == needleExact || token.startsWith("${needleExact}_")
            }
        }
    }
}

/** Real "is Chrome running" probe backed by `pidof <package>` through Shizuku. */
class ShizukuChromeRunningProbe(
    private val chromePackage: String = CHROME_STABLE_PACKAGE,
) : () -> ChromeRunningResult {

    override fun invoke(): ChromeRunningResult {
        val result = ShizukuShell.execute(arrayOf("pidof", chromePackage))
        val output = result.stdout.trim()
        return when {
            result.exitCode == 0 && output.isNotEmpty() -> ChromeRunningResult.Running
            result.exitCode == 1 && output.isEmpty() -> ChromeRunningResult.NotRunning
            else -> ChromeRunningResult.Unknown
        }
    }

    companion object {
        const val CHROME_STABLE_PACKAGE = "com.android.chrome"
    }
}
