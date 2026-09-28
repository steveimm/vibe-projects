package id.steveimm.pocketpilot.platform

import android.util.Log
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.TimeUnit
import rikka.shizuku.Shizuku

internal object ShizukuShell {
    private const val TAG = "ShizukuShell"
    private const val DRAIN_TIMEOUT_MS = 1_000L

    data class Result(val exitCode: Int, val stdout: String, val stderr: String)

    /** Blocking entry point for callers already on an IO worker. */
    fun execute(command: Array<String>, timeoutSec: Long = 5L): Result {
        return try {
            runDrained(newProcess(command), timeoutSec).also { result ->
                if (result.exitCode != 0) Log.w(TAG, "Shell exit ${result.exitCode}: ${result.stderr}")
            }
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "Shell command failed", e)
            Result(-1, "", "")
        }
    }

    internal fun runDrained(process: Process, timeoutSec: Long): Result {
        val stdout = ByteArrayOutputStream()
        val stderr = ByteArrayOutputStream()
        try {
            process.outputStream.close()
            val outputReader = drain("Shizuku-stdout", process.inputStream, stdout)
            val errorReader = drain("Shizuku-stderr", process.errorStream, stderr)
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(timeoutSec)
            val exitCode = waitForExit(process, deadline)
            if (exitCode == null) {
                Log.w(TAG, "Shell command timed out")
                return Result(-1, "", "")
            }

            outputReader.join(DRAIN_TIMEOUT_MS)
            errorReader.join(DRAIN_TIMEOUT_MS)
            if (outputReader.isAlive || errorReader.isAlive) {
                Log.w(TAG, "Shell output did not close after exit")
                return Result(-1, "", "")
            }
            return Result(exitCode, stdout.toString(Charsets.UTF_8.name()), stderr.toString(Charsets.UTF_8.name()))
        } finally {
            runCatching { process.destroy() }
            runCatching { process.inputStream.close() }
            runCatching { process.errorStream.close() }
            runCatching { process.outputStream.close() }
        }
    }

    private fun drain(name: String, source: InputStream, sink: ByteArrayOutputStream): Thread = Thread({
        try {
            source.use { it.copyTo(sink) }
        } catch (_: IOException) {
            // Destroying a timed-out process closes its pipes while readers are active.
        }
    }, name).apply {
        isDaemon = true
        start()
    }

    private fun waitForExit(process: Process, deadline: Long): Int? {
        var sleepMs = 10L
        while (true) {
            if (Thread.currentThread().isInterrupted) throw InterruptedException()
            try {
                return process.exitValue()
            } catch (_: IllegalThreadStateException) {
            } catch (e: IllegalArgumentException) {
                // ShizukuRemoteProcess uses this exception while its child is running.
                if (e.message?.contains("process hasn't exited") != true) throw e
            }

            val remaining = deadline - System.nanoTime()
            if (remaining <= 0) return null
            Thread.sleep(minOf(TimeUnit.NANOSECONDS.toMillis(remaining) + 1, sleepMs))
            sleepMs = minOf(sleepMs * 2, 100L)
        }
    }

    private fun newProcess(command: Array<String>): Process {
        val parameters = arrayOf(Array<String>::class.java, Array<String>::class.java, String::class.java)
        val method = try {
            Shizuku::class.java.getMethod("newProcess", *parameters)
        } catch (_: NoSuchMethodException) {
            Shizuku::class.java.getDeclaredMethod("newProcess", *parameters)
        }
        method.isAccessible = true
        return method.invoke(null, command, null, null) as Process
    }
}
