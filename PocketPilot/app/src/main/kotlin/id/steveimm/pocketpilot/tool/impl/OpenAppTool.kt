package id.steveimm.pocketpilot.tool.impl

import android.util.Log
import id.steveimm.pocketpilot.platform.ActionResult
import id.steveimm.pocketpilot.protocol.AppTier
import id.steveimm.pocketpilot.tool.action.buildObservation
import id.steveimm.pocketpilot.tool.ToolExecutionContext
import id.steveimm.pocketpilot.tool.ToolExecutionResult
import id.steveimm.pocketpilot.tool.ToolInvocation
import id.steveimm.pocketpilot.tool.ToolSpec
import id.steveimm.pocketpilot.tool.ValidationResult
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import org.json.JSONArray
import org.json.JSONObject

/** Well-known app aliases for name → package resolution. */
internal object AppAliases {
    val PACKAGE_MAP = mapOf(
        "google maps" to "com.google.android.apps.maps",
        "maps" to "com.google.android.apps.maps",
        "chrome" to "com.android.chrome",
        "google chrome" to "com.android.chrome",
        "browser" to "com.android.chrome",
        "gmail" to "com.google.android.gm",
        "email" to "com.google.android.gm",
        "youtube" to "com.google.android.youtube",
        "play store" to "com.android.vending",
        "google play" to "com.android.vending",
        "files" to "com.google.android.apps.nbu.files",
        "phone" to "com.android.dialer",
        "dialer" to "com.android.dialer",
        "camera" to "com.android.camera",
        "settings" to "com.android.settings",
        "messages" to "com.google.android.apps.messaging",
        "sms" to "com.google.android.apps.messaging",
        "contacts" to "com.android.contacts",
        "calendar" to "com.google.android.calendar",
        "clock" to "com.google.android.deskclock",
        "calculator" to "com.google.android.calculator",
        "photos" to "com.google.android.apps.photos",
        "drive" to "com.google.android.apps.docs",
        "keep" to "com.google.android.keep",
        "google keep" to "com.google.android.keep",
        "simple calendar" to "com.simplemobiletools.calendar.pro",
        "simple calendar pro" to "com.simplemobiletools.calendar.pro",
        "simple draw pro" to "com.simplemobiletools.draw.pro",
        "audio recorder" to "com.dimowner.audiorecorder",
        "pro expense" to "com.arduia.expense",
        "markor" to "net.gsantner.markor",
    )
}

/** OpenAppTool — Launch an app by name. */
class OpenAppTool : ToolSpec {

    companion object {
        private const val TAG = "OpenAppTool"
    }

    override val name: String = "open_app"

    override val description: String = """
Launch an app by name. Always use this to open apps — do NOT navigate the app drawer or home screen manually.
If the target app is already in the foreground, this returns success without relaunching it.
If the app is not found, suggestions will be provided.
""".trimIndent()

    override val parameterSchema: JSONObject by lazy {
        JSONObject().apply {
            put("type", "object")
            put("properties", JSONObject().apply {
                put("app_name", JSONObject().apply {
                    put("type", "string")
                    put("description", "Name of the app to open (e.g., 'Gmail', 'Settings', 'Chrome'). Case-insensitive.")
                })
            })
            put("required", JSONArray(listOf("app_name")))
            put("additionalProperties", false)
        }
    }

    override fun validate(params: JSONObject): ValidationResult {
        val appName = params.optString("app_name", "").trim()
        if (appName.isEmpty()) {
            return ValidationResult.Invalid("open_app requires app_name")
        }
        return ValidationResult.Valid
    }

    override fun createInvocation(params: JSONObject): ToolInvocation {
        val appName = params.optString("app_name", "").trim()

        val desc = "Open app: $appName"

        return OpenAppInvocation(params, desc, appName)
    }
}

/** Executable invocation for opening an app. */
private class OpenAppInvocation(
    override val params: JSONObject,
    private val description: String,
    private val appName: String
) : ToolInvocation {

    companion object {
        private const val TAG = "OpenAppInvocation"
        private const val UI_SETTLE_DELAY_MS = 800L
        private const val SUGGESTION_LIMIT = 5
    }

    override val toolName: String = "open_app"

    override fun getDescription(): String = description

    override suspend fun execute(context: ToolExecutionContext): ToolExecutionResult {
        if (context.isCancelled()) {
            return ToolExecutionResult.Cancelled("Cancelled before execution")
        }

        val apps = context.platform.getInstalledApps()
        val searchTerm = appName.lowercase().trim()

        val match = resolveInstalledApp(apps, appName)

        if (match == null) {
            val suggestions = findSimilarApps(searchTerm, apps)
            val suggestionText = if (suggestions.isNotEmpty()) {
                "Similar apps: ${suggestions.joinToString(", ")}. Try again with the correct name."
            } else {
                "No similar apps found on this device."
            }
            Log.w(TAG, "App not found: '$appName'. $suggestionText")
            return ToolExecutionResult.Failure(
                "App not found: '$appName'. $suggestionText"
            )
        }

        val targetPackage = match.packageName
        Log.d(TAG, "Resolved '$appName' -> $targetPackage (${match.label})")

        val classifier = context.appClassifier
        if (classifier != null && classifier.classify(targetPackage) == AppTier.BLOCKED) {
            Log.w(TAG, "Denied open_app to BLOCKED package: $targetPackage")
            return ToolExecutionResult.Failure(
                "Cannot open '${match.label}': app is blocked by security policy."
            )
        }

        val currentPackage = context.platform.getCurrentPackageName()
        if (currentPackage != null && currentPackage == targetPackage) {
            Log.d(TAG, "'${match.label}' is already in the foreground, skipping launch")
            return ToolExecutionResult.Success(
                output = "'${match.label}' is already in the foreground. No action needed."
            )
        }

        val result = context.platform.launchApp(targetPackage)

        return when (result) {
            is ActionResult.Success -> {
                delay(UI_SETTLE_DELAY_MS)

                val snapshot = try {
                    context.platform.captureScreen()
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to capture screen after app launch", e)
                    null
                }

                val observation = snapshot?.let {
                    buildObservation(it, context.platform, context.appClassifier)
                }

                ToolExecutionResult.Success(
                    output = "Launched ${match.label} ($targetPackage)",
                    observation = observation
                )
            }
            is ActionResult.Failure -> ToolExecutionResult.Failure(
                "Failed to launch '${match.label}': ${result.reason}"
            )
            else -> ToolExecutionResult.Failure("Unexpected result: $result")
        }
    }

    /** Find similar app names for error suggestions. */
    private fun findSimilarApps(
        searchTerm: String,
        apps: List<id.steveimm.pocketpilot.platform.AppInfo>,
        limit: Int = SUGGESTION_LIMIT
    ): List<String> {
        val term = searchTerm.lowercase()
        val termChars = term.toSet()

        data class ScoredApp(val label: String, val score: Int)

        val scored = apps.mapNotNull { app ->
            val label = app.label.lowercase()
            val score = when {
                // Prefix match (e.g. "gma" → "gmail")
                label.startsWith(term) || term.startsWith(label) -> 4
                // Substring match
                label.contains(term) || term.contains(label) -> 3
                // Package name contains term
                app.packageName.lowercase().contains(term) -> 2
                // Character overlap > 50%
                termChars.isNotEmpty() &&
                    termChars.intersect(label.toSet()).size > termChars.size / 2 -> 1
                else -> 0
            }
            if (score > 0) ScoredApp(app.label, score) else null
        }

        return scored
            .sortedByDescending { it.score }
            .take(limit)
            .map { it.label }
    }
}

internal fun resolveInstalledApp(apps: List<id.steveimm.pocketpilot.platform.AppInfo>, name: String): id.steveimm.pocketpilot.platform.AppInfo? {
    val query = name.trim()
    if (query.isEmpty()) return null
    return apps.find { it.label.equals(query, ignoreCase = true) }
        ?: apps.find { it.packageName.equals(query, ignoreCase = true) }
        ?: apps.find { it.packageName == AppAliases.PACKAGE_MAP[query.lowercase()] }
        ?: apps.find { it.label.contains(query, ignoreCase = true) }
        ?: apps.find { '.' in query && it.packageName.contains(query, ignoreCase = true) }
}
