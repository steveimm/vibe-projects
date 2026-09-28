package id.steveimm.pocketpilot.browser.setup

import id.steveimm.pocketpilot.platform.ShizukuShell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runInterruptible

interface ShellRunner {
    suspend fun run(command: Array<String>): ShellResult

    data class ShellResult(val exitCode: Int, val stdout: String)
}

internal class ShizukuShellRunner(
    private val timeoutSec: Long = 5L,
) : ShellRunner {
    override suspend fun run(command: Array<String>): ShellRunner.ShellResult = runInterruptible(Dispatchers.IO) {
        val result = ShizukuShell.execute(command, timeoutSec)
        ShellRunner.ShellResult(result.exitCode, result.stdout)
    }
}
