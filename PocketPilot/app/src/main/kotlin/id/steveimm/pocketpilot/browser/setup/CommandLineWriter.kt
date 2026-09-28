package id.steveimm.pocketpilot.browser.setup

import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Idempotently writes Chrome's command-line file at `/data/local/tmp/chrome-command-line` so Chrome binds the `chrome_devtools_remote`
 * abstract socket once the user has flipped the `enable-command-line-on-non-rooted-devices` flag and restarted Chrome. */
class CommandLineWriter(
    private val shell: ShellRunner = ShizukuShellRunner(),
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {

    /** @return [Outcome.AlreadyCorrect] when the file already had the expected content (no-op), [Outcome.Written] when we wrote it
     * successfully, [Outcome.Failed] when the shell call failed (Shizuku unavailable, exit non-zero, etc.). */
    suspend fun ensureWritten(): Outcome = withContext(ioDispatcher) {
        val current = runCatching { shell.run(arrayOf("sh", "-c", "cat $TARGET_PATH 2>/dev/null")) }
            .onFailure { if (it is CancellationException) throw it }
            .getOrNull()
        if (current?.exitCode == 0 && current.stdout.trim() == DESIRED_CONTENT.trim()) {
            return@withContext Outcome.AlreadyCorrect
        }
        val write = runCatching {
            shell.run(arrayOf("sh", "-c", "echo $QUOTED_CONTENT > $TARGET_PATH"))
        }.getOrElse {
            if (it is CancellationException) throw it
            Log.w(TAG, "shell write threw", it)
            return@withContext Outcome.Failed
        }
        if (write.exitCode == 0) Outcome.Written else Outcome.Failed
    }

    enum class Outcome { AlreadyCorrect, Written, Failed }

    companion object {
        const val TARGET_PATH = "/data/local/tmp/chrome-command-line"

        /** Chrome reads the first token (process name) and ignores it; everything after is appended to the command line. */
        const val DESIRED_CONTENT =
            "_ --remote-debugging-socket-name=chrome_devtools_remote --enable-features=NetworkService"

        /** Single-quoted form for `sh -c "echo '...' > path"`. */
        private const val QUOTED_CONTENT = "'$DESIRED_CONTENT'"
        private const val TAG = "ChromeCmdLineWriter"
    }
}
