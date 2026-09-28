package id.steveimm.pocketpilot.app

import id.steveimm.pocketpilot.llm.ModelIdValidator
import id.steveimm.pocketpilot.llm.ServerBaseUrlValidator

internal fun serverConfigurationError(settings: AppSettingsState): String? =
    ServerBaseUrlValidator.validate(settings.serverBaseUrl).exceptionOrNull()?.message
        ?: ModelIdValidator.validate(settings.serverModelId).exceptionOrNull()?.message
