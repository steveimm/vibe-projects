package id.steveimm.pocketpilot.ui.onboarding

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import id.steveimm.pocketpilot.ui.settings.SettingsAlertCard
import id.steveimm.pocketpilot.ui.settings.AlertTone
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.onboarding.DemoStepState
import id.steveimm.pocketpilot.onboarding.PermissionStepState
import id.steveimm.pocketpilot.onboarding.StepOutcome
import id.steveimm.pocketpilot.onboarding.StepOutcomes
import id.steveimm.pocketpilot.onboarding.WizardStep

@Composable
fun PermissionStepContent(
    step: WizardStep,
    state: PermissionStepState,
    onOpenSettings: () -> Unit,
    onSkip: () -> Unit,
    onContinue: () -> Unit = {}
) {
    val copy = permissionStepCopy(step)
    val uriHandler = LocalUriHandler.current
    var detailsExpanded by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxWidth()) {
        // Description
        Text(
            text = copy.description,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        // Optional expandable disclosure (LLM data flow + privacy policy).
        if (copy.extendedDescription != null) {
            TextButton(onClick = { detailsExpanded = !detailsExpanded }) {
                Text(if (detailsExpanded) "Hide details" else "Data & privacy details")
            }
            if (detailsExpanded) {
                Text(
                    text = copy.extendedDescription,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                TextButton(onClick = {
                    uriHandler.openUri("https://github.com/steveimm/vibe-projects/blob/main/PocketPilot/PRIVACY_POLICY.md")
                }) { Text("Privacy policy") }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        if (state == PermissionStepState.Unsatisfied) {
            SettingsAlertCard(message = copy.consequence, tone = AlertTone.Error)
        }

        Spacer(modifier = Modifier.weight(1f))

        // Primary CTA
        when (state) {
            PermissionStepState.Checking -> {
                LoadingButton(text = "Checking...")
            }
            PermissionStepState.Satisfied -> {
                Button(
                    onClick = onContinue,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(
                        imageVector = Icons.Filled.Check,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Continue")
                }
            }
            else -> {
                Button(
                    onClick = onOpenSettings,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = state != PermissionStepState.OpeningSettings
                ) {
                    Text(copy.ctaLabel)
                }
            }
        }

        // Skip (Battery only)
        if (step == WizardStep.Battery && state != PermissionStepState.Satisfied) {
            TextButton(
                onClick = onSkip,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
            ) {
                Text("Continue without this")
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
fun DemoStepContent(
    state: DemoStepState,
    onRunDemo: () -> Unit,
    onSkip: () -> Unit,
    onGoToServerStep: () -> Unit = {}
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        when (state) {
            DemoStepState.Ready, DemoStepState.Preflight -> {
                Text(
                    text = "Ask your model to open Android Settings. This demo does not change any device setting.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            DemoStepState.Running -> {
                Text(
                    text = "Opening Settings...",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            is DemoStepState.Success -> {
                Text(
                    text = state.message,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.secondary
                )
            }
            is DemoStepState.Failure -> {
                Text(
                    text = state.reason,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.error
                )
            }
            DemoStepState.Skipped -> {}
        }

        Spacer(modifier = Modifier.weight(1f))

        when (state) {
            DemoStepState.Ready -> {
                Button(onClick = onRunDemo, modifier = Modifier.fillMaxWidth()) {
                    Text("Run demo")
                }
                TextButton(
                    onClick = onSkip,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp)
                ) {
                    Text("Skip for now")
                }
            }
            DemoStepState.Preflight, DemoStepState.Running -> {
                LoadingButton(text = "Running...")
            }
            is DemoStepState.Failure -> {
                Button(onClick = onRunDemo, modifier = Modifier.fillMaxWidth()) {
                    Text("Try again")
                }
                TextButton(onClick = onGoToServerStep) { Text("Check model server") }
                TextButton(
                    onClick = onSkip,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp)
                ) {
                    Text("Skip for now")
                }
            }
            is DemoStepState.Success, DemoStepState.Skipped -> {
                SuccessButton(text = "Demo complete")
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
fun CompleteStepContent(
    outcomes: StepOutcomes,
    accessibilityGranted: Boolean,
    overlayGranted: Boolean,
    batteryGranted: Boolean,
    onFinish: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Checklist — permission rows reflect live state (auto-skipped steps
        // never write StepOutcome.Done, so reading `outcomes` here would lie).
        LiveStatusRow("Accessibility service", accessibilityGranted)
        LiveStatusRow("Display overlay", overlayGranted)
        LiveStatusRow("Background activity", batteryGranted)
        OutcomeRow("Model server", outcomes.modelServer)
        OutcomeRow("Demo task", outcomes.demo)

        Spacer(modifier = Modifier.weight(1f))

        Button(
            onClick = onFinish,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Start using PocketPilot")
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
private fun LoadingButton(text: String) {
    Button(
        onClick = {},
        modifier = Modifier.fillMaxWidth(),
        enabled = false
    ) {
        CircularProgressIndicator(
            modifier = Modifier.size(16.dp),
            strokeWidth = 2.dp,
            color = MaterialTheme.colorScheme.onSurface
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(text)
    }
}

@Composable
private fun SuccessButton(text: String) {
    Button(
        onClick = {},
        modifier = Modifier.fillMaxWidth(),
        enabled = false,
        colors = ButtonDefaults.buttonColors(
            disabledContainerColor = MaterialTheme.colorScheme.secondary,
            disabledContentColor = MaterialTheme.colorScheme.onSecondary
        )
    ) {
        Icon(
            imageVector = Icons.Filled.Check,
            contentDescription = null,
            modifier = Modifier.size(16.dp)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(text)
    }
}

@Composable
private fun LiveStatusRow(label: String, granted: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp, horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val (icon, tint) = if (granted) {
            Icons.Filled.Check to MaterialTheme.colorScheme.secondary
        } else {
            Icons.Filled.Close to MaterialTheme.colorScheme.error
        }
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = tint
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onBackground
        )
    }
}

@Composable
private fun OutcomeRow(label: String, outcome: StepOutcome) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp, horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val (icon, tint, suffix) = when (outcome) {
            StepOutcome.Done -> Triple(
                Icons.Filled.Check,
                MaterialTheme.colorScheme.secondary,
                ""
            )
            StepOutcome.Skipped -> Triple(
                Icons.Filled.Close,
                MaterialTheme.colorScheme.onSurfaceVariant,
                " (skipped)"
            )
            StepOutcome.Pending -> Triple(
                Icons.Filled.Close,
                MaterialTheme.colorScheme.error,
                ""
            )
        }

        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = tint
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = "$label$suffix",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onBackground
        )
    }
}

private data class PermissionCopy(
    val description: String,
    val consequence: String,
    val ctaLabel: String,
    val extendedDescription: String? = null
)

private fun permissionStepCopy(step: WizardStep): PermissionCopy = when (step) {
    WizardStep.Accessibility -> PermissionCopy(
        description = "Allow PocketPilot to read the screen and perform taps for the tasks you request.",
        consequence = "Without Accessibility, PocketPilot cannot automate tasks.",
        ctaLabel = "Open accessibility settings",
        extendedDescription = "During a task, screenshots and screen text are sent to your configured model server. " +
            "Floating controls remain available between tasks."
    )
    WizardStep.Overlay -> PermissionCopy(
        description = "The floating controls show progress and let you stop, take over, or return to PocketPilot.",
        consequence = "Without Overlay, you won't see controls while the agent works in other apps.",
        ctaLabel = "Grant Overlay permission"
    )
    WizardStep.Battery -> PermissionCopy(
        description = "Some phones aggressively stop background work. Allowing unrestricted battery use makes long tasks reliable.\n\nThis is optional but recommended.",
        consequence = "Long tasks may stop when the app is backgrounded.",
        ctaLabel = "Allow background activity"
    )
    else -> error("Not a permission step: $step")
}
