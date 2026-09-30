package id.steveimm.pocketpilot.ui.common

import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.R

@Composable
fun PilotMark(
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.primary,
    size: Dp = 24.dp,
    contentDescription: String? = null,
) {
    Icon(painterResource(R.drawable.ic_pilot), contentDescription, modifier.size(size), tint = color)
}
