package id.steveimm.pocketpilot.ui.settings

import id.steveimm.pocketpilot.llm.LLMProvider
import id.steveimm.pocketpilot.llm.OtherBaseUrlValidator

/** Pure refresh-button gating logic — when discovery's prerequisites are met for [provider]. Designed so the Compose layer renders a
 * disabled button with a tooltip naming the missing piece without re-doing validation. */
object RefreshButtonGate {

    sealed interface State {
        data object Enabled : State
        data class Disabled(val reason: String) : State
    }

    fun evaluate(
        provider: LLMProvider,
        apiKey: String,
        otherBaseUrl: String,
    ): State {
        return when (provider) {
            LLMProvider.OPENROUTER -> {
                if (apiKey.isBlank()) State.Disabled("Enter your OpenRouter API key first")
                else State.Enabled
            }
            LLMProvider.OTHER -> {
                if (apiKey.isBlank()) State.Disabled("Enter your API key first")
                else {
                    val urlResult = OtherBaseUrlValidator.validate(otherBaseUrl)
                    if (urlResult.isFailure) State.Disabled(
                        urlResult.exceptionOrNull()?.message ?: "Base URL is invalid"
                    ) else State.Enabled
                }
            }
            else -> State.Disabled("Refresh is only supported for OpenRouter and Other")
        }
    }
}
