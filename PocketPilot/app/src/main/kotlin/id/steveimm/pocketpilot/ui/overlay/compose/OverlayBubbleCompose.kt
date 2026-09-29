package id.steveimm.pocketpilot.ui.overlay.compose

import android.view.MotionEvent
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInteropFilter
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.ui.capsule.surface.StatusPawGlyph

@OptIn(ExperimentalComposeUiApi::class)
@Composable
internal fun OverlayBubbleCompose(
    expanded: Boolean,
    status: String,
    statusColor: Color,
    onToggle: () -> Unit,
    onTouch: (MotionEvent) -> Boolean,
) {
    val action = if (expanded) "Minimize PocketPilot controls" else "Expand PocketPilot controls"
    Surface(
        modifier = Modifier.fillMaxSize().padding(4.dp).semantics {
            role = Role.Button
            contentDescription = action
            stateDescription = status
            onClick(action) { onToggle(); true }
        }.pointerInteropFilter(onTouchEvent = onTouch),
        shape = CircleShape,
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(2.dp, statusColor),
        shadowElevation = 4.dp,
    ) {
        Box(contentAlignment = Alignment.Center) {
            if (expanded) Icon(Icons.Rounded.Close, contentDescription = null, tint = statusColor)
            else StatusPawGlyph(color = statusColor, size = 26.dp)
        }
    }
}
