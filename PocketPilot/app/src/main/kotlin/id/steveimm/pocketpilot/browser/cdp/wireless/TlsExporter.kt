package id.steveimm.pocketpilot.browser.cdp.wireless

import java.io.IOException
import javax.net.ssl.SSLSocket
import org.conscrypt.Conscrypt

/** Wraps Conscrypt's RFC 5705 TLS exporter. */
internal object TlsExporter {

    fun export(socket: SSLSocket, label: String, context: ByteArray?, length: Int): ByteArray {
        return try {
            Conscrypt.exportKeyingMaterial(socket, label, context, length)
        } catch (t: Throwable) {
            throw IOException(
                "TLS exporter call failed: ${t.message}. SSLSocket impl=${socket.javaClass.name}; " +
                    "Conscrypt.isConscrypt=${runCatching { Conscrypt.isConscrypt(socket) }.getOrNull()}",
                t,
            )
        }
    }
}
