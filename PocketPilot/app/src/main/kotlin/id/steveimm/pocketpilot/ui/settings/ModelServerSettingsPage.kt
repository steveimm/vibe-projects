package id.steveimm.pocketpilot.ui.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import id.steveimm.pocketpilot.app.AppSettingsState
import id.steveimm.pocketpilot.ui.theme.PageMastheadDrillDown
import id.steveimm.pocketpilot.ui.theme.pocketPilot

@Composable
internal fun ModelServerSettingsPage(settings: AppSettingsState, onBack: () -> Unit, onClose: () -> Unit) {
    Column(Modifier.fillMaxWidth()) {
        PageMastheadDrillDown(title = "Model server", onBack = onBack, onClose = onClose)
        Column(Modifier.verticalScroll(rememberScrollState()).padding(MaterialTheme.pocketPilot.spacing.lg)) {
            ModelServerForm(settings)
        }
    }
}
