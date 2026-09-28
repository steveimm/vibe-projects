package id.steveimm.pocketpilot.tool.impl

import id.steveimm.pocketpilot.browser.cdp.shizuku.DevtoolsSetupError
import kotlinx.coroutines.CancellationException

/** Production capability gate. */
class DefaultBrowserScriptCapabilityGate(
    private val isExperimentalEnabled: () -> Boolean,
    private val preflight: suspend () -> Unit,
    private val invokerFactory: () -> BrowserScriptInvoker,
) : BrowserScriptCapabilityGate {

    override suspend fun acquire(): BrowserScriptCapabilityGate.Outcome {
        if (!isExperimentalEnabled()) {
            return unavailable(
                CODE_EXPERIMENTAL_DISABLED,
                "Browser automation is disabled. Enable it in app settings before invoking " +
                    "browser_script.",
            )
        }
        try {
            preflight()
        } catch (ce: CancellationException) {
            throw ce
        } catch (e: DevtoolsSetupError) {
            return fromSetupError(e)
        }
        return BrowserScriptCapabilityGate.Outcome.Available(invokerFactory())
    }

    private fun unavailable(code: String, reason: String) =
        BrowserScriptCapabilityGate.Outcome.Unavailable(code, reason)

    private fun fromSetupError(e: DevtoolsSetupError) = unavailable(
        e.code,
        e.message ?: "browser_script capability error: ${e.code}",
    )

    companion object {
        const val CODE_EXPERIMENTAL_DISABLED: String = "experimental_disabled"
    }
}
