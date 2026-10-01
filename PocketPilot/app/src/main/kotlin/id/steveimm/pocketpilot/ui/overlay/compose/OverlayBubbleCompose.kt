package id.steveimm.pocketpilot.ui.overlay.compose

import android.view.MotionEvent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import id.steveimm.pocketpilot.ui.theme.PocketPilotMotion
import id.steveimm.pocketpilot.ui.theme.pocketPilot
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInteropFilter
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.ui.common.PilotMark

@OptIn(ExperimentalComposeUiApi::class)
@Composable
internal fun OverlayBubbleCompose(
    capturedForDismissal: Boolean,
    onDismiss: () -> Unit,
    status: String,
    onToggle: () -> Unit,
    onTouch: (MotionEvent) -> Boolean,
) {
    val action = "Expand PocketPilot controls"
    val scale by animateFloatAsState(if (capturedForDismissal) 0.65f else 1f,
        tween(if (PocketPilotMotion.reducedMotion()) 0 else PocketPilotMotion.Quick), label = "Dismiss bubble")
    Surface(
        modifier = Modifier.fillMaxSize().padding(4.dp).graphicsLayer { scaleX = scale; scaleY = scale }.semantics {
            role = Role.Button
            contentDescription = action
            stateDescription = status
            customActions = listOf(CustomAccessibilityAction("Dismiss") { onDismiss(); true })
            onClick(action) { onToggle(); true }
        }.pointerInteropFilter(onTouchEvent = onTouch),
        shape = CircleShape,
        color = MaterialTheme.colorScheme.primary,
        shadowElevation = MaterialTheme.pocketPilot.elevation.floating,
    ) {
        Box(contentAlignment = Alignment.Center) {
            PilotMark(color = MaterialTheme.colorScheme.onPrimary, size = 26.dp)
        }
    }
}
