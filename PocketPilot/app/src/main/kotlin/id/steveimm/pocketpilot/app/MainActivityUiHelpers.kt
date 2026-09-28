package id.steveimm.pocketpilot.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import id.steveimm.pocketpilot.llm.LFMLLMClient
import id.steveimm.pocketpilot.ui.settings.ModelLoadingStatus
import id.steveimm.pocketpilot.ui.viewer.VirtualDisplayViewerActivity

internal fun LFMLLMClient.ModelLoadingState.toUiStatus(): ModelLoadingStatus {
    return when (this) {
        is LFMLLMClient.ModelLoadingState.NotLoaded -> ModelLoadingStatus.Idle
        is LFMLLMClient.ModelLoadingState.Downloading -> ModelLoadingStatus.Downloading(progress)
        is LFMLLMClient.ModelLoadingState.Loading -> ModelLoadingStatus.Loading
        is LFMLLMClient.ModelLoadingState.Ready -> ModelLoadingStatus.Ready
        is LFMLLMClient.ModelLoadingState.Error -> ModelLoadingStatus.Error(message)
    }
}

internal fun openAccessibilitySettings(context: Context) {
    context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
}

internal fun openOverlaySettings(context: Context) {
    val intent =
        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}"))
    context.startActivity(intent)
}

internal fun openViewer(context: Context) {
    context.startActivity(Intent(context, VirtualDisplayViewerActivity::class.java))
}
