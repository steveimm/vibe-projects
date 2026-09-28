package id.steveimm.pocketpilot.app

import android.content.Context
import id.steveimm.pocketpilot.auth.ServerCredentialStore

object ServerCredentialStoreHolder {
    @Volatile private var instance: ServerCredentialStore? = null

    fun get(context: Context): ServerCredentialStore = instance ?: synchronized(this) {
        instance ?: ServerCredentialStore(context.applicationContext).also { instance = it }
    }
}
