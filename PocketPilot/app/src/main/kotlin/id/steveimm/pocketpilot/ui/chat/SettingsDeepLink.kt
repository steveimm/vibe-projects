package id.steveimm.pocketpilot.ui.chat

enum class SettingsPage { HOME, MODEL_SERVER }

data class SettingsDeepLink(val page: SettingsPage = SettingsPage.MODEL_SERVER)
