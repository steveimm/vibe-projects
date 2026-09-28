package id.steveimm.pocketpilot.tool

import android.content.Context
import android.util.Log
import id.steveimm.pocketpilot.app.AppSettingsStore

/** Application-scoped [AppClassifier] singleton. */
object AppClassifierHolder {
    private const val TAG = "AppClassifierHolder"

    @Volatile private var instance: AppClassifier? = null

    fun get(context: Context): AppClassifier {
        instance?.let { return it }
        return synchronized(this) {
            instance ?: build(context.applicationContext).also { instance = it }
        }
    }

    private fun build(appContext: Context): AppClassifier {
        val store = AppSettingsStore(appContext)
        val bundled = AppClassifier.loadBundledTiers(appContext.assets)
        val initialOverrides = store.loadUserAppOverrides()
        Log.i(
            TAG,
            "Bootstrapping AppClassifier: ${bundled.size} bundled tiers, ${initialOverrides.size} user overrides"
        )
        return AppClassifier(
            appTiers = bundled,
            initialUserOverrides = initialOverrides,
            onUserOverridesChanged = { snapshot ->
                store.saveUserAppOverrides(snapshot)
            }
        )
    }
}
