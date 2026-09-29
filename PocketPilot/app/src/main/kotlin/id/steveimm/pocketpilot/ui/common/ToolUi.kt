package id.steveimm.pocketpilot.ui.common

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Apps
import androidx.compose.material.icons.rounded.Build
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.HourglassEmpty
import androidx.compose.material.icons.rounded.Keyboard
import androidx.compose.material.icons.rounded.SwipeVertical
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.UnfoldMore
import androidx.compose.ui.graphics.vector.ImageVector
import id.steveimm.pocketpilot.tool.ToolName

data class ToolDisplay(
    val name: String,
    val icon: ImageVector
)

fun formatToolName(toolName: String): String = resolveToolDisplay(toolName).name

fun getToolIcon(toolName: String): ImageVector = resolveToolDisplay(toolName).icon

private fun resolveToolDisplay(toolName: String): ToolDisplay {
    return when (val tool = ToolName.from(toolName)) {
        ToolName.Tap, ToolName.LongPress -> ToolDisplay(tool.displayName, Icons.Rounded.TouchApp)
        ToolName.Swipe -> ToolDisplay(tool.displayName, Icons.Rounded.SwipeVertical)
        ToolName.TypeText -> ToolDisplay(tool.displayName, Icons.Rounded.Keyboard)
        ToolName.OpenApp -> ToolDisplay(tool.displayName, Icons.Rounded.Apps)
        ToolName.ReadScreen -> ToolDisplay(tool.displayName, Icons.Rounded.HourglassEmpty)
        ToolName.SystemButton -> ToolDisplay(tool.displayName, Icons.Rounded.TouchApp)
        ToolName.AskUser -> ToolDisplay(tool.displayName, Icons.Rounded.Build)
        ToolName.TermuxShell -> ToolDisplay(tool.displayName, Icons.Rounded.Build)
        is ToolName.Unknown -> ToolDisplay(tool.displayName, Icons.Rounded.Build)
    }
}
