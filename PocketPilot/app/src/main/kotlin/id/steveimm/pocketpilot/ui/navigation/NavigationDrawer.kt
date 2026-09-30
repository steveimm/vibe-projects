package id.steveimm.pocketpilot.ui.navigation

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Delete
import com.composables.icons.lucide.Lucide
import com.composables.icons.lucide.SlidersHorizontal
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.history.model.SessionInfo
import id.steveimm.pocketpilot.ui.session.TimeUtils
import id.steveimm.pocketpilot.ui.theme.AppWindowInsets
import id.steveimm.pocketpilot.ui.theme.RootPageHeader
import id.steveimm.pocketpilot.ui.theme.pocketPilot

/** NavigationDrawer - Side drawer containing session history and settings access. */
@Composable
fun NavigationDrawerContent(
    sessions: List<SessionInfo>,
    listState: LazyListState,
    onSessionSelect: (SessionInfo) -> Unit,
    onNewSession: () -> Unit,
    onDeleteSession: (SessionInfo) -> Unit,
    onSettingsClick: () -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier
) {
    ModalDrawerSheet(
        modifier = modifier.widthIn(max = 320.dp).fillMaxWidth(),
        drawerContainerColor = MaterialTheme.colorScheme.surface,
        windowInsets = AppWindowInsets.statusBars  // Handle status bar at container level
    ) {
        val spacing = MaterialTheme.pocketPilot.spacing
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Header
            DrawerHeader(onClose = onClose)

            // New session button
            NewSessionButton(
                onClick = onNewSession,
                modifier = Modifier.padding(horizontal = 16.dp)
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Session list (scrollable, takes remaining space)
            Box(modifier = Modifier.weight(1f)) {
                if (sessions.isEmpty()) {
                    EmptySessionsMessage(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(32.dp)
                    )
                } else {
                    LazyColumn(
                        state = listState,
                        contentPadding = PaddingValues(horizontal = spacing.md, vertical = spacing.sm),
                        verticalArrangement = Arrangement.spacedBy(spacing.xs)
                    ) {
                        items(
                            items = sessions,
                            key = { it.id }
                        ) { session ->
                            DrawerSessionItem(
                                session = session,
                                onClick = { onSessionSelect(session) },
                                onDelete = { onDeleteSession(session) }
                            )
                        }
                    }
                }
            }

            // Settings entry at bottom - no divider, uses surface background to distinguish
            SettingsEntry(
                onClick = onSettingsClick,
                modifier = Modifier
                    .padding(bottom = spacing.sm)  // Consistent bottom spacing
                    .windowInsetsPadding(WindowInsets.navigationBars)
            )
        }
    }
}

/** History drawer header. */
@Composable
private fun DrawerHeader(
    onClose: () -> Unit
) {
    RootPageHeader(
        title = "Chats",
        onClose = onClose,
        modifier = Modifier.padding(top = 12.dp, bottom = 12.dp),
    )
}

/** Start a new conversation. */
@Composable
private fun NewSessionButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        border = BorderStroke(
            1.dp,
            MaterialTheme.colorScheme.primary
        ),
        colors = ButtonDefaults.outlinedButtonColors(
            contentColor = MaterialTheme.colorScheme.primary
        )
    ) {
        Icon(
            imageVector = Icons.Rounded.Add,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text("New chat")
    }
}

/** Individual session item in drawer. */
@Composable
private fun DrawerSessionItem(
    session: SessionInfo,
    onClick: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    var showDeleteConfirm by remember { mutableStateOf(false) }
    val rowShape = MaterialTheme.shapes.small
    val isCorrupted = session.isCorrupted
    val rowColor = when {
        isCorrupted -> MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.24f)
        session.isActive -> MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.36f)
        else -> MaterialTheme.colorScheme.surfaceVariant
    }
    val rowBorder = when {
        isCorrupted -> BorderStroke(1.dp, MaterialTheme.colorScheme.error)
        session.isActive -> BorderStroke(1.dp, MaterialTheme.colorScheme.primary)
        else -> null
    }
    val rowStateDescription = when {
        isCorrupted -> "Unreadable chat. Cannot open."
        session.isActive -> "Current chat"
        else -> null
    }
    val statusText = when {
        isCorrupted -> "Unreadable chat"
        session.isActive -> "Current chat"
        else -> null
    }
    val statusColor = when {
        isCorrupted -> MaterialTheme.colorScheme.error
        session.isActive -> MaterialTheme.colorScheme.primary
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("Delete chat") },
            text = { Text("This permanently deletes this chat and stops any task using it.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteConfirm = false
                        onDelete()
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) { Text("Cancel") }
            }
        )
    }

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .clip(rowShape)
            .then(
                if (isCorrupted) {
                    Modifier
                } else {
                    Modifier.clickable(
                        onClickLabel = "Open chat",
                        role = Role.Button,
                        onClick = onClick
                    )
                }
            )
            .semantics {
                if (rowStateDescription != null) {
                    stateDescription = rowStateDescription
                }
            },
        color = rowColor,
        shape = rowShape,
        border = rowBorder
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = session.displayTitle,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )

                if (statusText != null) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = statusText,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = statusColor,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                Spacer(modifier = Modifier.height(4.dp))

                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = TimeUtils.formatMessageCount(session.messageCount),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    // Separator dot
                    Box(
                        modifier = Modifier
                            .size(3.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.onSurfaceVariant)
                    )

                    Text(
                        text = TimeUtils.formatRelativeTime(session.lastUpdated),
                        style = MaterialTheme.pocketPilot.monoSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            IconButton(
                onClick = { showDeleteConfirm = true },
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Rounded.Delete,
                    contentDescription = "Delete chat",
                    modifier = Modifier.size(18.dp),
                    tint = MaterialTheme.pocketPilot.mutedText
                )
            }
        }
    }
}

/** Empty state message. */
@Composable
private fun EmptySessionsMessage(
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "No saved chats",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

    }
}

/** Settings entry at bottom of drawer. Uses surface color (no fill) to distinguish from session items above. */
@Composable
private fun SettingsEntry(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Lucide.SlidersHorizontal,
            contentDescription = null,
            modifier = Modifier.size(24.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.width(12.dp))

        Text(
            text = "Settings",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}
