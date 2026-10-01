package id.steveimm.pocketpilot.ui.capsule.surface

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import id.steveimm.pocketpilot.ui.chat.components.ChatMarkdown
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Terminal
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material.icons.rounded.OpenInNew
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.protocol.ApprovalDecision
import id.steveimm.pocketpilot.protocol.ApprovalScope
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.ui.capsule.NavAction
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleContext
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleRenderSpec
import id.steveimm.pocketpilot.ui.overlay.model.NavSpec
import id.steveimm.pocketpilot.ui.theme.PocketPilotMotion
import id.steveimm.pocketpilot.ui.theme.pocketPilot
import com.composables.icons.lucide.Lucide
import com.composables.icons.lucide.TriangleAlert

/** SmartCapsuleSurface — orchestrator composable for the Smart Capsule. */
@Composable
fun SmartCapsuleSurface(
    mode: CapsuleMode,
    isStopPending: Boolean,
    platformMode: PlatformMode,
    context: CapsuleContext,
    onSend: (String) -> Unit,
    onSupplement: (String) -> Unit,
    onTakeover: () -> Unit,
    onResume: () -> Unit,
    onSupplementAndResume: (String) -> Unit = { text ->
        onSupplement(text)
        onResume()
    },
    onStop: () -> Unit,
    onUserResponse: (String, String) -> Unit,
    onApprovalResponse: (String, ApprovalDecision, ApprovalScope, String) -> Unit = { _, _, _, _ -> },
    onNavigate: (NavAction) -> Unit,
    modifier: Modifier = Modifier,
    transientThought: String? = null,
    onInputFocusChanged: (Boolean) -> Unit = {},
    onInputSubmitted: () -> Unit = {},
    autoFocusInput: Boolean = false,
    inputActive: Boolean = true,
    lastToolCall: String? = null,
    inputDraft: MutableState<String>? = null,
    pendingInputText: String = "",
    onPendingInputConsumed: () -> Unit = {},
    startupError: String? = null,
    onDismissStartupError: () -> Unit = {},
    onStartupErrorClick: (() -> Unit)? = null,
    voice: VoiceMicDeps? = null,
) {
    val renderSpec = remember(mode, isStopPending, transientThought) {
        val baseSpec = CapsuleRenderSpec.from(mode, isStopPending)
        if (transientThought.isNullOrBlank()) baseSpec
        else baseSpec.copy(thought = CapsuleRenderSpec.ThoughtSpec(transientThought))
    }
    val navSpec = remember(context, platformMode, mode) {
        NavSpec.from(context, platformMode, mode = mode)
    }
    val isTaskActive = mode !is CapsuleMode.Hidden
    val shape = MaterialTheme.shapes.large
    val spacing = MaterialTheme.pocketPilot.spacing


    Surface(
        modifier = modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        shape = shape,
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = spacing.sm)
                .padding(top = if (isTaskActive || navSpec.showApp) spacing.sm else 0.dp),
        ) {
            if (isTaskActive || navSpec.showApp || navSpec.showWatch) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    if (navSpec.showApp) {
                        IconButton(onClick = { onNavigate(NavAction.NEW_CONVERSATION) }) {
                            Icon(Icons.Rounded.Add, "New chat", Modifier.size(20.dp))
                        }
                    }
                    Box(Modifier.weight(1f)) {
                        if (isTaskActive) CapsuleStatusLine(spec = renderSpec)
                    }
                    if (navSpec.showApp) {
                        IconButton(onClick = { onNavigate(NavAction.OPEN_APP) }) {
                            Icon(Icons.Rounded.OpenInNew, "Open PocketPilot", Modifier.size(20.dp))
                        }
                    }
                    if (navSpec.showWatch) IconButton(onClick = { onNavigate(NavAction.OPEN_VIEWER) }) {
                        Icon(Icons.Rounded.Visibility, "Open viewer", Modifier.size(20.dp))
                    }
                    if (navSpec.showClose) IconButton(onClick = { onNavigate(NavAction.CLOSE_OVERLAY) }) {
                        Icon(Icons.Rounded.Close, "Minimize to bubble", Modifier.size(20.dp))
                    }
                }
            }
            if (isTaskActive) {
                if (mode !is CapsuleMode.Done || context != CapsuleContext.MAIN_APP) {
                    Column(Modifier.weight(1f, fill = false).heightIn(max = 240.dp).verticalScroll(rememberScrollState())) {
                        if (renderSpec.expandedBody != null) {
                            CapsuleDivider()
                            CapsuleDetailBody(text = renderSpec.expandedBody)
                        }
                    }
                    if (!lastToolCall.isNullOrBlank() && mode !is CapsuleMode.Done && mode !is CapsuleMode.Error) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Rounded.Terminal, "Last tool call", Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(Modifier.width(8.dp))
                            Text(lastToolCall, style = MaterialTheme.pocketPilot.monoBody,
                                color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        }
                    }
                    if (renderSpec.buttons.primary != null || renderSpec.buttons.stop != null) CapsuleControlBar(
                        spec = renderSpec,
                        mode = mode,
                        onTakeover = onTakeover,
                        onResume = onResume,
                        onStop = onStop,
                        onDone = { callId -> onUserResponse(callId, "done") },
                        onApprovalResponse = onApprovalResponse,
                    )
                }
            }

            renderSpec.input?.let { input ->
                if (isTaskActive) {
                    CapsuleDivider()
                }
                if (startupError != null) {
                    StartupErrorBanner(
                        message = startupError,
                        onDismiss = onDismissStartupError,
                        onClick = onStartupErrorClick,
                    )
                }
                CapsuleInputBar(
                    spec = input,
                    active = inputActive,
                    mode = mode,
                    platformMode = platformMode,
                    context = context,
                    inputDraft = inputDraft,
                    pendingInputText = pendingInputText,
                    onPendingInputConsumed = onPendingInputConsumed,
                    autoFocusInput = autoFocusInput,
                    onInputFocusChanged = onInputFocusChanged,
                    onSubmit = { text ->
                        when (mode) {
                            is CapsuleMode.Hidden, is CapsuleMode.Done, is CapsuleMode.Error -> onSend(text)
                            is CapsuleMode.WaitingForInput -> onUserResponse(mode.callId, text)
                            is CapsuleMode.Takeover -> onSupplementAndResume(text)
                            else -> onSupplement(text)
                        }
                        onInputSubmitted()
                    },
                    voice = voice,
                )
            }
        }
    }
}

@Composable
private fun CapsuleDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(vertical = 6.dp),
        color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.28f),
        thickness = 1.dp,
    )
}

@Composable
private fun CapsuleDetailBody(text: String) {
    ChatMarkdown(
        text = text,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 2.dp),
    )
}

@Composable
private fun StartupErrorBanner(
    message: String,
    onDismiss: () -> Unit,
    onClick: (() -> Unit)? = null,
) {
    val surfaceModifier = Modifier
        .fillMaxWidth()
        .padding(vertical = 4.dp)
        .let {
            if (onClick != null) {
                it
                    .minimumInteractiveComponentSize()
                    .clickable(
                        role = Role.Button,
                        onClickLabel = "Open settings",
                    ) {
                        onClick()
                    }
                    .semantics { contentDescription = "Startup error: $message" }
            } else {
                it
            }
        }
    Surface(
        modifier = surfaceModifier,
        color = MaterialTheme.colorScheme.errorContainer,
        shape = MaterialTheme.shapes.medium,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(end = 4.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Lucide.TriangleAlert,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.error,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = message,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onErrorContainer,
                modifier = Modifier.weight(1f),
            )
            IconButton(onClick = onDismiss) {
                Icon(
                    imageVector = Icons.Rounded.Close,
                    contentDescription = "Dismiss error",
                    tint = MaterialTheme.colorScheme.onErrorContainer,
                )
            }
        }
    }
}

@Composable
private fun CapsuleStatusLine(spec: CapsuleRenderSpec) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        spec.dot?.let { dot ->
            val color = dot.status.toStatusColor()
            if (dot.pulsing && !PocketPilotMotion.reducedMotion()) {
                CircularProgressIndicator(Modifier.size(14.dp), color = color, strokeWidth = 2.dp)
            } else Box(Modifier.size(6.dp).background(color, CircleShape))
            Spacer(Modifier.width(8.dp))
        }
        Text(spec.thought.text, style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}
