package id.steveimm.pocketpilot.ui.chat

import id.steveimm.pocketpilot.llm.AuthMode
import id.steveimm.pocketpilot.llm.LLMProvider

/** Settings pages available for deep-linking from runtime banners. */
enum class SettingsPage { HOME, LLM_AUTH }

/** Instruction to the settings host to open a specific page/tab. */
data class SettingsDeepLink(
    val page: SettingsPage = SettingsPage.LLM_AUTH,
    val authTab: AuthMode? = null,
    val provider: LLMProvider? = null,
)
