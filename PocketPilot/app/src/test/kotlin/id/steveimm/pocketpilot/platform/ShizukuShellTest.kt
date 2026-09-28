package id.steveimm.pocketpilot.platform

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.runInterruptible
import kotlinx.coroutines.withTimeout
import java.util.concurrent.TimeUnit
import org.junit.Assume
import org.junit.Test

class ShizukuShellTest {

    @Test
    fun `runDrained returns full stdout for output larger than pipe buffer`() {
        val sh = findShell()
        Assume.assumeTrue("no POSIX shell on PATH", sh != null)

        val process = ProcessBuilder(sh!!, "-c", "seq 1 100000").start()

        val result = ShizukuShell.runDrained(process, timeoutSec = 10L)

        // Pre-fix this assertion failed: exitCode was -1 (timeout) and stdout was empty.
        assertThat(result.exitCode).isEqualTo(0)
        val lines = result.stdout.lineSequence().filter { it.isNotEmpty() }.toList()
        assertThat(lines.size).isEqualTo(100_000)
        assertThat(lines.first()).isEqualTo("1")
        assertThat(lines.last()).isEqualTo("100000")
    }

    @Test
    fun `runDrained returns small stdout`() {
        val sh = findShell()
        Assume.assumeTrue("no POSIX shell on PATH", sh != null)

        val process = ProcessBuilder(sh!!, "-c", "echo hello").start()

        val result = ShizukuShell.runDrained(process, timeoutSec = 5L)

        assertThat(result.exitCode).isEqualTo(0)
        assertThat(result.stdout.trim()).isEqualTo("hello")
    }

    @Test
    fun `runDrained reports non-zero exit code`() {
        val sh = findShell()
        Assume.assumeTrue("no POSIX shell on PATH", sh != null)

        val process = ProcessBuilder(sh!!, "-c", "exit 42").start()

        val result = ShizukuShell.runDrained(process, timeoutSec = 5L)

        assertThat(result.exitCode).isEqualTo(42)
        assertThat(result.stdout).isEmpty()
    }

    @Test
    fun `runDrained drains stderr in parallel without blocking stdout`() {
        val sh = findShell()
        Assume.assumeTrue("no POSIX shell on PATH", sh != null)

        // Emit ~150 KiB to BOTH stdout and stderr concurrently. Pre-fix, even with the stdout drain in place, leaving stderr undrained on
        // a child that writes a lot of stderr could block the child indefinitely (write to stderr blocks once stderr's pipe buffer fills).
        val script = "seq 1 30000 & seq 1 30000 1>&2; wait"
        val process = ProcessBuilder(sh!!, "-c", script).start()

        val result = ShizukuShell.runDrained(process, timeoutSec = 10L)

        assertThat(result.exitCode).isEqualTo(0)
        val stdoutLines = result.stdout.lineSequence().filter { it.isNotEmpty() }.toList()
        assertThat(stdoutLines.size).isEqualTo(30_000)
        assertThat(result.stderr.lineSequence().filter { it.isNotEmpty() }.count()).isEqualTo(30_000)
    }

    @Test(timeout = 5_000)
    fun `runDrained closes stdin for commands waiting for EOF`() {
        val sh = findShell()
        Assume.assumeTrue("no POSIX shell on PATH", sh != null)
        val process = ProcessBuilder(sh!!, "-c", "cat; echo finished").start()

        val result = ShizukuShell.runDrained(process, timeoutSec = 2L)

        assertThat(result.exitCode).isEqualTo(0)
        assertThat(result.stdout.trim()).isEqualTo("finished")
    }

    @Test(timeout = 5_000)
    fun `runDrained destroys the child when its deadline expires`() {
        val sh = findShell()
        Assume.assumeTrue("no POSIX shell on PATH", sh != null)
        val process = ProcessBuilder(sh!!, "-c", "exec sleep 30").start()
        try {
            val result = ShizukuShell.runDrained(process, timeoutSec = 0L)

            assertThat(result.exitCode).isEqualTo(-1)
            assertThat(process.waitFor(2, TimeUnit.SECONDS)).isTrue()
        } finally {
            process.destroyForcibly()
        }
    }

    @Test(timeout = 5_000)
    fun `cancelling an interruptible shell wait destroys the child`() = runBlocking {
        val sh = findShell()
        Assume.assumeTrue("no POSIX shell on PATH", sh != null)
        val process = ProcessBuilder(sh!!, "-c", "exec sleep 30").start()
        val started = CompletableDeferred<Unit>()
        try {
            val job = launch {
                runInterruptible(Dispatchers.IO) {
                    started.complete(Unit)
                    ShizukuShell.runDrained(process, timeoutSec = 30L)
                }
            }
            started.await()
            withTimeout(2_000) { job.cancelAndJoin() }

            assertThat(job.isCancelled).isTrue()
            assertThat(process.waitFor(2, TimeUnit.SECONDS)).isTrue()
        } finally {
            process.destroyForcibly()
        }
    }

    private fun findShell(): String? =
        listOf("/bin/bash", "/usr/bin/bash", "/bin/sh", "/usr/bin/sh")
            .firstOrNull { java.io.File(it).canExecute() }
}
