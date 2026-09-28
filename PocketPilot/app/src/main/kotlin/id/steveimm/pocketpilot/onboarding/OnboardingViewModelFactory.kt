package id.steveimm.pocketpilot.onboarding

import android.content.Context
import id.steveimm.pocketpilot.app.AppSettingsState
import id.steveimm.pocketpilot.app.AuthStoreHolder
import id.steveimm.pocketpilot.llm.ModelCatalog
import kotlinx.coroutines.CoroutineScope

/** Assembles an [OnboardingViewModel] with the app-scoped [id.steveimm.pocketpilot.auth.AuthStore]. */
object OnboardingViewModelFactory {
    fun create(
        context: Context,
        store: OnboardingStore,
        settingsState: AppSettingsState,
        modelCatalog: ModelCatalog,
        permissionMonitor: PermissionStateMonitor,
        demoController: OnboardingDemoController,
        scope: CoroutineScope
    ): OnboardingViewModel = OnboardingViewModel(
        store = store,
        settingsState = settingsState,
        modelCatalog = modelCatalog,
        permissionMonitor = permissionMonitor,
        authStore = AuthStoreHolder.get(context.applicationContext),
        demoController = demoController,
        scope = scope
    )
}
