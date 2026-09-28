package id.steveimm.pocketpilot.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.app.AppSettingsState
import id.steveimm.pocketpilot.app.ServerCredentialStoreHolder
import id.steveimm.pocketpilot.llm.ModelCatalogRepositoryHolder
import id.steveimm.pocketpilot.llm.ModelEntry
import id.steveimm.pocketpilot.llm.ModelIdValidator
import id.steveimm.pocketpilot.llm.ServerBaseUrlValidator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun ModelServerForm(settings: AppSettingsState, onSaved: () -> Unit = {}) {
    val context = LocalContext.current.applicationContext
    val credentials = remember(context) { ServerCredentialStoreHolder.get(context) }
    val repository = remember(context) { ModelCatalogRepositoryHolder.get(context) }
    val scope = rememberCoroutineScope()
    var url by rememberSaveable { mutableStateOf(settings.serverBaseUrl) }
    var model by rememberSaveable { mutableStateOf(settings.serverModelId) }
    var key by remember { mutableStateOf("") }
    var keyEdited by remember { mutableStateOf(false) }
    var keyLoading by remember { mutableStateOf(false) }
    var keyRequest by remember { mutableStateOf(0) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var models by remember { mutableStateOf<List<ModelEntry>>(emptyList()) }
    var menuOpen by remember { mutableStateOf(false) }
    val normalizedUrl = ServerBaseUrlValidator.validate(url).getOrNull()
    val validatedModel = ModelIdValidator.validate(model).getOrNull()

    LaunchedEffect(normalizedUrl) {
        val request = ++keyRequest
        key = ""
        keyEdited = false
        models = emptyList()
        message = null
        error = null
        keyLoading = normalizedUrl != null
        try {
            if (normalizedUrl != null) {
                val savedKey = withContext(Dispatchers.IO) { credentials.apiKey(normalizedUrl) }
                if (request == keyRequest && !keyEdited) key = savedKey
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            if (request == keyRequest) error = "Could not read the saved server key: ${e.message}"
        } finally {
            if (request == keyRequest) keyLoading = false
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Connect to an OpenAI-compatible Chat Completions server you run.")
        OutlinedTextField(
            value = url,
            onValueChange = { url = it; error = null },
            label = { Text("Server URL") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
            placeholder = { Text("http://192.168.1.10:8000/v1") },
            supportingText = { Text("Use the API base URL or the full /chat/completions URL.") },
            singleLine = true,
            enabled = !busy,
            isError = url.isNotBlank() && normalizedUrl == null,
            modifier = Modifier.fillMaxWidth().testTag("server-url"),
        )
        OutlinedTextField(
            value = key,
            onValueChange = { keyEdited = true; key = it },
            label = { Text("API key (optional)") },
            supportingText = { Text("Leave blank if your server does not require authentication.") },
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
            singleLine = true,
            enabled = !busy && !keyLoading,
            modifier = Modifier.fillMaxWidth().testTag("server-api-key"),
        )
        OutlinedButton(
            enabled = normalizedUrl != null && !busy && !keyLoading,
            onClick = {
                val endpoint = normalizedUrl ?: return@OutlinedButton
                val token = key
                busy = true
                error = null
                scope.launch {
                    try {
                        models = repository.refresh(endpoint, token)
                        message = if (models.isEmpty()) "No models listed. You can enter a model ID manually." else null
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        error = "Could not list models. Enter the model ID manually, or check the server."
                    } finally {
                        busy = false
                    }
                }
            },
            modifier = Modifier.testTag("load-server-models"),
        ) { Text(if (busy) "Working…" else "Load models") }
        if (models.isNotEmpty()) {
            Box {
                OutlinedButton(onClick = { menuOpen = true }) { Text("Choose a listed model") }
                DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }, modifier = Modifier.heightIn(max = 280.dp)) {
                    models.forEach { entry ->
                        DropdownMenuItem(text = { Text(entry.displayName) }, onClick = { model = entry.modelId; menuOpen = false })
                    }
                }
            }
        }
        OutlinedTextField(
            value = model,
            onValueChange = { model = it; message = null },
            label = { Text("Model ID") },
            supportingText = { Text("Use the exact model ID served by your endpoint.") },
            singleLine = true,
            enabled = !busy,
            isError = model.isNotBlank() && validatedModel == null,
            modifier = Modifier.fillMaxWidth().testTag("server-model-id"),
        )
        if (normalizedUrl?.startsWith("http://") == true) Text("HTTP sends requests without encryption. Use a trusted network.")
        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        message?.let { Text(it) }
        Button(
            enabled = normalizedUrl != null && validatedModel != null && !busy && !keyLoading,
            onClick = {
                val endpoint = normalizedUrl ?: return@Button
                val id = validatedModel ?: return@Button
                val token = key
                busy = true
                error = null
                scope.launch {
                    try {
                        withContext(Dispatchers.IO) { credentials.setApiKey(endpoint, token) }
                        settings.updateServer(endpoint, id)
                        message = "Server settings saved."
                        onSaved()
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        error = "Could not save server settings: ${e.message}"
                    } finally {
                        busy = false
                    }
                }
            },
            modifier = Modifier.fillMaxWidth().testTag("save-model-server"),
        ) { Text("Save server") }
    }
}
