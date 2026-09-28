package id.steveimm.pocketpilot.browser.cdp.wireless

import java.security.Security
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.conscrypt.Conscrypt

/** Registers the JCE/JCA providers our wireless-ADB stack depends on, without changing global provider priority. Both have
 * Android-specific gotchas: */
internal object WirelessAdbProviders {

    @Volatile private var installed = false
    private val lock = Any()

    fun ensure() {
        if (installed) return
        synchronized(lock) {
            if (installed) return
            installBouncyCastle()
            installConscrypt()
            installed = true
        }
    }

    private fun installBouncyCastle() {
        val existing = Security.getProvider(BouncyCastleProvider.PROVIDER_NAME)
        if (existing == null || existing.javaClass != BouncyCastleProvider::class.java) {
            Security.removeProvider(BouncyCastleProvider.PROVIDER_NAME)
            // Append at end: leaves global provider order untouched. Browser code that needs the
            // real bcprov-jdk18on uses provider-qualified getInstance / setProvider.
            Security.addProvider(BouncyCastleProvider())
        }
    }

    private fun installConscrypt() {
        // Conscrypt requires its native lib; skip silently in host-JVM unit tests where
        // conscrypt_jni isn't present (the keystore tests don't need TLS).
        runCatching {
            val existing = Security.getProvider(CONSCRYPT_PROVIDER_NAME)
            if (existing == null) {
                // Append rather than insertProviderAt(_, 1): unqualified SSLContext.getInstance
                // calls elsewhere keep the platform default. We always qualify with "Conscrypt".
                Security.addProvider(Conscrypt.newProvider())
            }
        }
    }

    private const val CONSCRYPT_PROVIDER_NAME = "Conscrypt"
}
