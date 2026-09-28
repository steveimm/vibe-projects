package id.steveimm.pocketpilot.debug

import android.util.Log
import id.steveimm.pocketpilot.app.AgentService
import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.perception.Perceptor
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal class DebugActionArtifacts(private val directory: File, private val logTag: String) {
    fun reset(): DebugActionArtifacts = apply {
        if (directory.exists()) directory.deleteRecursively()
        directory.mkdirs()
    }

    suspend fun captureSnapshot(service: AgentService): ScreenSnapshot? = try {
        withContext(Dispatchers.Main) {
            val root = service.rootInActiveWindow
            val metrics = service.resources.displayMetrics
            Perceptor.snapshot(root, metrics.widthPixels, metrics.heightPixels)
        }
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        Log.w(logTag, "Failed to capture snapshot", e)
        null
    }

    fun writeTree(filename: String, snapshot: ScreenSnapshot) {
        try {
            File(directory, filename).writeText(Perceptor.toPromptJson(snapshot))
        } catch (e: Exception) {
            Log.w(logTag, "Failed to write $filename", e)
        }
    }

    fun finish(json: JSONObject) {
        try {
            File(directory, "result.json").writeText(json.toString(2))
            File(directory, ".done").createNewFile()
        } catch (e: Exception) {
            Log.e(logTag, "Failed to write result", e)
        }
    }
}

internal fun debugActionTimestamp(): String {
    val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
    format.timeZone = TimeZone.getTimeZone("UTC")
    return format.format(Date())
}
