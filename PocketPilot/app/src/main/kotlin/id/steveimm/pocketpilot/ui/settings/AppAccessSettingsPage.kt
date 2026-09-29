package id.steveimm.pocketpilot.ui.settings

import id.steveimm.pocketpilot.ui.theme.PageMastheadDrillDown
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.AppTier
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.ui.theme.pocketPilot
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

import androidx.compose.material3.OutlinedTextField

private enum class AppFilter(val label: String) { All("All"), Allow("Allow"), Ask("Ask"), Reject("Reject") }

@Composable
internal fun AppAccessSettingsPage(
    appClassifier: AppClassifier,
    approvalMode: ApprovalMode = ApprovalMode.SMART,
    onBack: () -> Unit,
    onClose: () -> Unit,
    rowsOverride: List<AppRow>? = null,
) {
    val context = LocalContext.current
    val overrides by appClassifier.userOverrides.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    var rows by remember { mutableStateOf<List<AppRow>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var reload by remember { mutableStateOf(0) }
    var query by rememberSaveable { mutableStateOf("") }
    var filter by rememberSaveable { mutableStateOf(AppFilter.All) }

    LaunchedEffect(context, rowsOverride, reload) {
        loading = true
        error = null
        try {
            rows = rowsOverride ?: withContext(Dispatchers.IO) { loadInstalledAppRows(context) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            error = "Could not read the installed app list."
        } finally {
            loading = false
        }
    }
    val visibleRows = remember(rows, query, filter, overrides) { filterRows(rows, appClassifier, query, filter) }
    Column(Modifier.fillMaxSize()) {
        PageMastheadDrillDown(title = "App Access", onBack = onBack, onClose = onClose)
        OutlinedTextField(
            value = query, onValueChange = { query = it }, label = { Text("Search apps") }, singleLine = true,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        )
        Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            AppFilter.entries.forEach { option ->
                SegmentChip(option.label, filter == option, { filter = option }, Modifier.weight(1f))
            }
        }
        if (approvalMode == ApprovalMode.AUTO_APPROVE) {
            Text("Auto-approve is enabled. Rejected apps stay blocked.", Modifier.padding(horizontal = 16.dp))
        }
        error?.let { message ->
            Text(message, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp))
            TextButton(onClick = { reload++ }) { Text("Retry") }
        }
        if (loading) Text("Loading apps…", Modifier.padding(16.dp))
        LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(visibleRows, key = { it.info.packageName }) { row ->
                val pkg = row.info.packageName
                val icon by produceState<ImageBitmap?>(null, pkg) { value = row.iconLoader() }
                Surface(shape = MaterialTheme.shapes.medium, color = MaterialTheme.colorScheme.surfaceContainerLow) {
                    Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            AppIcon(icon)
                            Column {
                                Text(row.info.label, style = MaterialTheme.typography.titleSmall)
                                Text(pkg, style = MaterialTheme.typography.bodySmall)
                            }
                        }
                        if (appClassifier.bundledTier(pkg) == AppTier.BLOCKED) {
                            RejectOnlyChip()
                        } else {
                            TierSegmentedSelector(appClassifier.classify(pkg)) { tier ->
                                scope.launch {
                                    try {
                                        appClassifier.setOverride(pkg, tier)
                                    } catch (e: CancellationException) {
                                        throw e
                                    } catch (e: Exception) {
                                        error = "Could not save app access."
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AppIcon(bitmap: ImageBitmap?) {
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(MaterialTheme.shapes.small)
            .background(MaterialTheme.colorScheme.surface),
        contentAlignment = Alignment.Center,
    ) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap,
                contentDescription = null,
                modifier = Modifier.size(32.dp),
            )
        } else {
            Box(
                modifier = Modifier
                    .size(12.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.pocketPilot.inkFaint),
            )
        }
    }
}

@Composable
private fun TierSegmentedSelector(
    selected: AppTier,
    onPick: (AppTier) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SegmentChip(
            label = "Allow",
            isSelected = selected == AppTier.NORMAL,
            onClick = { onPick(AppTier.NORMAL) },
            modifier = Modifier.weight(1f),
        )
        SegmentChip(
            label = "Ask",
            isSelected = selected == AppTier.CAUTIOUS,
            onClick = { onPick(AppTier.CAUTIOUS) },
            modifier = Modifier.weight(1f),
        )
        SegmentChip(
            label = "Reject",
            isSelected = selected == AppTier.BLOCKED,
            onClick = { onPick(AppTier.BLOCKED) },
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun RejectOnlyChip() {
    Row(modifier = Modifier.fillMaxWidth()) {
        Surface(
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.primaryContainer,
            shape = MaterialTheme.shapes.small,
            tonalElevation = 2.dp,
        ) {
            Row(
                modifier = Modifier.padding(vertical = MaterialTheme.pocketPilot.spacing.sm, horizontal = MaterialTheme.pocketPilot.spacing.sm),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = Icons.Outlined.Lock,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "Reject",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                )
            }
        }
    }
}

@Composable
internal fun SegmentChip(
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier
            .minimumInteractiveComponentSize()
            .selectable(
                selected = isSelected,
                role = Role.RadioButton,
                onClick = onClick,
            )
            .semantics {
                contentDescription = label
                selected = isSelected
                stateDescription = if (isSelected) "Selected" else "Not selected"
            },
        color = if (isSelected) MaterialTheme.colorScheme.primaryContainer
        else MaterialTheme.colorScheme.surface,
        shape = MaterialTheme.shapes.small,
        tonalElevation = if (isSelected) 2.dp else 0.dp,
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(vertical = MaterialTheme.pocketPilot.spacing.sm, horizontal = MaterialTheme.pocketPilot.spacing.sm),
            style = MaterialTheme.typography.labelMedium,
            color = if (isSelected) MaterialTheme.colorScheme.onPrimaryContainer
            else MaterialTheme.colorScheme.onSurface,
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
    }
}

private fun filterRows(
    rows: List<AppRow>,
    classifier: AppClassifier,
    query: String,
    filter: AppFilter,
): List<AppRow> {
    val q = query.lowercase()
    return rows.filter { row ->
        val matchesQuery = q.isEmpty() ||
            row.info.label.lowercase().contains(q) ||
            row.info.packageName.lowercase().contains(q)
        if (!matchesQuery) return@filter false

        val pkg = row.info.packageName
        when (filter) {
            AppFilter.All -> true
            AppFilter.Allow -> classifier.classify(pkg) == AppTier.NORMAL
            AppFilter.Ask -> classifier.classify(pkg) == AppTier.CAUTIOUS
            AppFilter.Reject -> classifier.classify(pkg) == AppTier.BLOCKED
        }
    }
}
