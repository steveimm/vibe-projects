package id.steveimm.pocketpilot.browser.cdp.wireless

import java.io.File

/** Parses /proc/net/tcp and /proc/net/tcp6 to extract the set of currently-LISTENing TCP ports. */
internal object ProcNetTcpListeners {

    private val TCP4 = File("/proc/net/tcp")
    private val TCP6 = File("/proc/net/tcp6")
    private const val LISTEN_STATE = "0A"

    fun snapshot(): Set<Int> = buildSet {
        addAll(parse(TCP4))
        addAll(parse(TCP6))
    }

    private fun parse(file: File): Set<Int> {
        val text = runCatching { file.readText() }.getOrNull() ?: return emptySet()
        val out = HashSet<Int>()
        // Skip the header line; data lines start with whitespace + index + ':'.
        for (line in text.lineSequence().drop(1)) {
            val cols = line.trim().split(Regex("\\s+"))
            if (cols.size < 4) continue
            val local = cols[1]
            val state = cols[3]
            if (state != LISTEN_STATE) continue
            val colon = local.lastIndexOf(':')
            if (colon < 0) continue
            val portHex = local.substring(colon + 1)
            val port = portHex.toIntOrNull(16) ?: continue
            if (port in 1..65535) out += port
        }
        return out
    }
}
