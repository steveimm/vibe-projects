package id.steveimm.pocketpilot.ui.settings

import id.steveimm.pocketpilot.platform.AppInfo
import id.steveimm.pocketpilot.platform.AppManager
import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.core.graphics.drawable.toBitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** UI-only row model for the App Access settings list. */
data class AppRow(
    val info: AppInfo,
    val iconLoader: suspend () -> ImageBitmap?
)

/** Scans installed apps via [AppManager.getInstalledApps] and attaches a lazy per-row icon loader. The scan itself is the same single
 * PackageManager query used elsewhere; only icons are deferred. */
fun loadInstalledAppRows(context: Context): List<AppRow> {
    val pm = context.packageManager
    return AppManager.getInstalledApps(pm).map { info ->
        AppRow(info = info, iconLoader = { loadAppIcon(pm, info.packageName) })
    }
}

internal suspend fun loadAppIcon(
    packageManager: PackageManager,
    packageName: String
): ImageBitmap? = withContext(Dispatchers.IO) {
    runCatching {
        packageManager.getApplicationIcon(packageName).toBitmap().asImageBitmap()
    }.getOrNull()
}
