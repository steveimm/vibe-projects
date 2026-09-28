package id.steveimm.pocketpilot.app

import android.content.Context
import id.steveimm.pocketpilot.auth.AuthCredential
import id.steveimm.pocketpilot.auth.AuthStore

/**
 * Application-scoped [AuthStore] singleton.
 *
 * The AuthStore owns per-provider generation counters and an in-memory fallback
 * cache. Creating it per-Activity (or per-session, per-reload) would cause the
 * UI layer and the session layer to observe divergent state on configuration
 * change, service rebind, or process reattach. One instance per process keeps
 * writes and reads coherent.
 */
object AuthStoreHolder {
    @Volatile private var instance: AuthStore? = null

    fun get(context: Context): AuthStore {
        instance?.let { return it }
        return synchronized(this) {
            instance ?: build(context.applicationContext).also { instance = it }
        }
    }

    private fun build(appContext: Context): AuthStore = AuthStore(
        context = appContext,
        refresher = { refreshToken ->
            when (val result = id.steveimm.pocketpilot.auth.OAuthTokenExchange.refresh(refreshToken)) {
                is id.steveimm.pocketpilot.auth.OAuthTokenExchange.Result.Success -> AuthCredential.OAuth(
                    accessToken = result.tokens.accessToken,
                    refreshToken = result.tokens.refreshToken,
                    expiresAt = result.tokens.expiresAt,
                    email = result.tokens.email,
                    idToken = result.tokens.idToken,
                )
                is id.steveimm.pocketpilot.auth.OAuthTokenExchange.Result.Error ->
                    throw IllegalStateException("OAuth refresh failed: ${result.message}")
            }
        }
    )
}
