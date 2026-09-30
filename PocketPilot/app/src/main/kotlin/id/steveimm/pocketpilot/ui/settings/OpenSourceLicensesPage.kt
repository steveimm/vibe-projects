package id.steveimm.pocketpilot.ui.settings

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.ui.theme.DetailPageHeader
import id.steveimm.pocketpilot.ui.theme.pocketPilot
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.io.IOException

@Serializable
internal data class LicenseEntry(
    val project: String? = null,
    val description: String? = null,
    val version: String? = null,
    val developers: List<String> = emptyList(),
    val url: String? = null,
    val year: String? = null,
    val licenses: List<LicenseTerm> = emptyList(),
    val dependency: String? = null,
)

@Serializable
internal data class LicenseTerm(
    val license: String? = null,
    @kotlinx.serialization.SerialName("license_url")
    val licenseUrl: String? = null,
)

private val LicenseJson = Json {
    ignoreUnknownKeys = true
    isLenient = true
}

private const val LICENSES_ASSET = "open_source_licenses.json"

internal suspend fun loadLicenseEntries(context: Context): List<LicenseEntry> =
    withContext(Dispatchers.IO) {
        context.assets.open(LICENSES_ASSET).use { input ->
            LicenseJson.decodeFromString<List<LicenseEntry>>(input.bufferedReader().readText())
        }
    }

private sealed interface LicenseLoadState {
    data object Loading : LicenseLoadState
    data class Loaded(val rows: List<LicenseEntry>) : LicenseLoadState
    data object Error : LicenseLoadState
}

@Composable
internal fun OpenSourceLicensesPage(
    onBack: () -> Unit,
    onClose: () -> Unit,
) {
    val context = LocalContext.current
    var reloadKey by remember { mutableStateOf(0) }
    var loadState by remember { mutableStateOf<LicenseLoadState>(LicenseLoadState.Loading) }

    LaunchedEffect(context, reloadKey) {
        loadState = LicenseLoadState.Loading
        loadState = loadLicenseState(context)
    }

    Column(modifier = Modifier.fillMaxSize()) {
        DetailPageHeader(title = "Open-source licenses", onBack = onBack, onClose = onClose)
        when (val state = loadState) {
            LicenseLoadState.Loading -> LicenseNotice(text = "Loading licenses…", loading = true)
            LicenseLoadState.Error -> LicenseNotice(
                text = "Could not load licenses",
                action = { TextButton(onClick = { reloadKey += 1 }) { Text("Retry") } },
            )
            is LicenseLoadState.Loaded -> {
                if (state.rows.isEmpty()) {
                    LicenseNotice(text = "No license information available")
                } else {
                    LicenseList(rows = state.rows, onOpenUrl = { url -> openUrl(context, url) })
                }
            }
        }
    }
}

private suspend fun loadLicenseState(context: Context): LicenseLoadState =
    try {
        val rows = loadLicenseEntries(context)
            .sortedBy { (it.project ?: it.dependency ?: "").lowercase() }
        LicenseLoadState.Loaded(rows)
    } catch (e: IOException) {
        LicenseLoadState.Error
    } catch (e: SerializationException) {
        LicenseLoadState.Error
    }

@Composable
private fun LicenseNotice(
    text: String,
    loading: Boolean = false,
    action: (@Composable () -> Unit)? = null,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(MaterialTheme.pocketPilot.spacing.lg),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (loading) CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
        Text(text, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
        action?.invoke()
    }
}

@Composable
private fun LicenseList(rows: List<LicenseEntry>, onOpenUrl: (String) -> Unit) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = MaterialTheme.pocketPilot.spacing.lg),
        verticalArrangement = Arrangement.spacedBy(MaterialTheme.pocketPilot.spacing.sm),
    ) {
        item { LicensesPreamble() }
        items(rows, key = { entry -> entry.dependency ?: entry.project ?: entry.hashCode().toString() }) { entry ->
            LicenseCard(entry = entry, onOpenUrl = onOpenUrl)
        }
        item { Spacer(modifier = Modifier.height(24.dp)) }
    }
}

@Composable
private fun LicensesPreamble() {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = MaterialTheme.pocketPilot.spacing.sm, bottom = MaterialTheme.pocketPilot.spacing.sm),
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = MaterialTheme.shapes.medium,
    ) {
        Column(modifier = Modifier.padding(MaterialTheme.pocketPilot.spacing.cardPadding), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                text = "PocketPilot is licensed under Apache 2.0.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}

@Composable
private fun LicenseCard(entry: LicenseEntry, onOpenUrl: (String) -> Unit) {
    val coordinates = entry.dependency.orEmpty()
    val version = entry.version?.takeIf(String::isNotBlank) ?: coordinates.split(':').getOrNull(2)
    val artifact = coordinates.removeSuffix(":$version")
    val title = entry.project?.takeIf(String::isNotBlank)?.substringAfterLast(':')
        ?: artifact.substringAfterLast(':')
    val licenseLine = entry.licenses.mapNotNull { it.license?.takeIf(String::isNotBlank) }
        .joinToString(", ")
        .ifBlank { "Unknown license" }
    val urlForClick = entry.licenses.firstNotNullOfOrNull { it.licenseUrl?.takeIf(String::isNotBlank) }
        ?: entry.url?.takeIf(String::isNotBlank)

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.medium)
            .let { if (urlForClick != null) it.clickable(role = Role.Button, onClickLabel = "Open license") { onOpenUrl(urlForClick) } else it },
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = MaterialTheme.shapes.medium,
    ) {
        Column(modifier = Modifier.padding(MaterialTheme.pocketPilot.spacing.cardPadding), verticalArrangement = Arrangement.spacedBy(MaterialTheme.pocketPilot.spacing.xs)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = title,
                    modifier = Modifier.weight(1f),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                if (version != null) {
                    Text(version, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            if (artifact.isNotBlank() && artifact != title) {
                Text(
                    text = artifact,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                text = licenseLine,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

private fun openUrl(context: Context, url: String) {
    try {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    } catch (_: ActivityNotFoundException) {
        Toast.makeText(context, "No app available to open this link", Toast.LENGTH_SHORT).show()
    } catch (_: SecurityException) {
        Toast.makeText(context, "Could not open this link", Toast.LENGTH_SHORT).show()
    }
}
