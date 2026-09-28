package id.steveimm.pocketpilot.browser.setup

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.Toast
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Opens Chrome on the `chrome://flags#enable-command-line-on-non-rooted-devices` page so the user can flip the unlock toggle. Chrome
 * blocks `chrome://` URLs from external intents for security, so the cascade is: */
class ChromeFlagDeepLink(
    private val context: Context,
    private val shellRunner: ShellRunner,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {

    /** Run the cascade and report the strategy that was attempted as the primary action. */
    suspend fun open(): Strategy = withContext(ioDispatcher) {
        when (tryActionView()) {
            ActionViewOutcome.Launched -> {
                // Additive fallback: even though we just launched the intent, Chrome can drop the chrome:// URL after handing the user to
                // its homepage. Copy + hint so the user has a one-paste recovery without re-tapping the CTA.
                copyUrlToClipboard()
                showToast(LAUNCH_HINT_TOAST)
                Strategy.ActionView
            }
            ActionViewOutcome.NoHandler, ActionViewOutcome.Threw -> {
                if (tryShizukuAmStart()) {
                    // Same silent-success risk as ActionView — `am start` exits 0 even when Chrome later refuses or drops the navigation.
                    // Always copy + hint so the user has a manual recovery.
                    copyUrlToClipboard()
                    showToast(LAUNCH_HINT_TOAST)
                    Strategy.ShizukuAmStart
                } else {
                    copyUrlToClipboard()
                    showToast(FALLBACK_TOAST)
                    Strategy.Clipboard
                }
            }
        }
    }

    /** Side-effect-free helper for the inline "Copy URL" button in [ToolsSection]: writes the flag URL to the clipboard and returns
     * whether the write succeeded so the caller can decide whether to show a confirming snackbar. */
    fun copyFlagUrlToClipboard(): Boolean = copyUrlToClipboard()

    enum class Strategy { ActionView, ShizukuAmStart, Clipboard }

    /** Three-state outcome to drive the cascade. */
    private enum class ActionViewOutcome { Launched, NoHandler, Threw }

    private fun tryActionView(): ActionViewOutcome = try {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(FLAG_URL))
            .setPackage(CHROME_PACKAGE)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val resolved = context.packageManager.resolveActivity(intent, 0)
        if (resolved == null) {
            Log.d(TAG, "ACTION_VIEW pre-check: no activity resolves chrome:// for $CHROME_PACKAGE")
            return ActionViewOutcome.NoHandler
        }
        context.startActivity(intent)
        ActionViewOutcome.Launched
    } catch (_: ActivityNotFoundException) {
        ActionViewOutcome.NoHandler
    } catch (e: SecurityException) {
        Log.w(TAG, "ACTION_VIEW for chrome://flags blocked: ${e.message}")
        ActionViewOutcome.Threw
    } catch (e: Throwable) {
        Log.w(TAG, "ACTION_VIEW for chrome://flags failed", e)
        ActionViewOutcome.Threw
    }

    private suspend fun tryShizukuAmStart(): Boolean = runCatching {
        val result = shellRunner.run(arrayOf(
            "am", "start",
            "-a", "android.intent.action.VIEW",
            "-d", FLAG_URL,
            "-n", "$CHROME_PACKAGE/$CHROME_MAIN_ACTIVITY",
        ))
        // `am start` exits 0 on dispatch even when the activity later refuses, but a shell-uid dispatch is what bypasses the
        // external-intent block — at this point Chrome's internal nav handler treats the URL as same-origin and renders it.
        result.exitCode == 0
    }.getOrElse {
        if (it is CancellationException) throw it
        Log.w(TAG, "Shizuku am start failed", it)
        false
    }

    private fun copyUrlToClipboard(): Boolean = try {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        if (cm != null) {
            cm.setPrimaryClip(ClipData.newPlainText("chrome flag URL", FLAG_URL))
            true
        } else {
            false
        }
    } catch (e: Throwable) {
        Log.w(TAG, "clipboard copy failed", e)
        false
    }

    private fun showToast(message: String) {
        // open() runs on Dispatchers.IO, which has no Looper — Toast.makeText fails with "Can't toast on a thread that has not called
        // Looper.prepare()".
        try {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                runCatching {
                    Toast.makeText(context, message, Toast.LENGTH_LONG).show()
                }.onFailure { Log.w(TAG, "toast failed", it) }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "toast scheduling failed", e)
        }
    }

    companion object {
        const val FLAG_URL =
            "chrome://flags/#enable-command-line-on-non-rooted-devices"
        const val CHROME_PACKAGE = "com.android.chrome"
        const val CHROME_MAIN_ACTIVITY = "com.google.android.apps.chrome.Main"
        const val LAUNCH_HINT_TOAST =
            "If Chrome didn't open chrome://flags, paste the URL from your clipboard into the address bar."
        const val FALLBACK_TOAST =
            "URL copied — paste in Chrome's address bar to open the flag page"
        private const val TAG = "ChromeFlagDeepLink"

        /** Pure-functional decision: given the result of each cascade attempt, return the strategy that should be reported as the
         * outcome. Tests use this to verify the cascade order without needing a real Context. */
        internal fun decideStrategy(
            actionViewLaunched: Boolean,
            shizukuAmStartSucceeded: Boolean,
        ): Strategy = when {
            actionViewLaunched -> Strategy.ActionView
            shizukuAmStartSucceeded -> Strategy.ShizukuAmStart
            else -> Strategy.Clipboard
        }
    }
}
