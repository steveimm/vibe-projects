package com.steveimm.fitnotes_plus

import android.Manifest
import android.content.pm.PackageManager
import android.app.Activity
import android.content.Intent
import android.content.SharedPreferences
import android.media.RingtoneManager
import android.os.Build
import android.net.Uri
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val channelName = "fitnotes/device"
    private var pendingPreview: MethodChannel.Result? = null
    private var pendingSound: MethodChannel.Result? = null
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private val restSound by lazy { RestAlertPlayer(this) }
    private val preferences by lazy { getSharedPreferences("fitnotes_timer", MODE_PRIVATE) }
    private var restEvents: EventChannel? = null
    private var restListener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        restEvents = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "fitnotes/rest_cleared").also { channel ->
            channel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    restListener?.let(preferences::unregisterOnSharedPreferenceChangeListener)
                    restListener = SharedPreferences.OnSharedPreferenceChangeListener { saved, key ->
                        if ((key == null || key == "deadline" || key == "paused") &&
                            !saved.contains("deadline") && !saved.getBoolean("paused", false)) events.success(null)
                    }.also(preferences::registerOnSharedPreferenceChangeListener)
                }

                override fun onCancel(arguments: Any?) {
                    restListener?.let(preferences::unregisterOnSharedPreferenceChangeListener)
                    restListener = null
                }
            })
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "keepAwake" -> {
                    if (call.argument<Boolean>("enabled") == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                "notificationSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    startActivity(intent)
                    result.success(null)
                }
                "saveFile" -> {
                    if (pendingSave != null) { result.error("busy", "A file picker is already open.", null) }
                    else {
                        pendingSave = result
                        pendingBytes = call.argument<ByteArray>("bytes")
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = call.argument<String>("mime") ?: "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                        }
                        startActivityForResult(intent, 71)
                    }
                }
                "previewRestSound" -> {
                    stopSoundPreview()
                    pendingPreview = result
                    restSound.play(call.argument<String>("uri")) {
                        pendingPreview?.success(null)
                        pendingPreview = null
                    }
                }
                "stopRestSoundPreview" -> { stopSoundPreview(); result.success(null) }
                "restSoundName" -> {
                    val uri = call.argument<String>("uri")
                    val name = try {
                        if (uri == null) "Soft chime"
                        else if (Uri.parse(uri).scheme !in listOf("content", "android.resource")) "Unavailable sound"
                        else {
                            val ringtone = RingtoneManager.getRingtone(this, Uri.parse(uri))
                            try { ringtone?.getTitle(this) ?: "Unavailable sound" } finally { ringtone?.stop() }
                        }
                    } catch (_: Exception) { "Unavailable sound" }
                    result.success(name)
                }
                "pickRestSound" -> {
                    if (pendingSound != null) result.error("busy", "A sound picker is already open.", null)
                    else {
                        stopSoundPreview()
                        pendingSound = result
                        try {
                            val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                                putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALL)
                                putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Rest sound")
                                putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                                putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, false)
                                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, call.argument<String>("uri")?.let(Uri::parse))
                            }
                            startActivityForResult(intent, 73)
                        } catch (error: Exception) {
                            pendingSound = null
                            result.error("sound_picker", "Could not open the device sound picker.", null)
                        }
                    }
                }
                "scheduleRest" -> {
                    preferences.edit().putLong("deadline", call.argument<Number>("deadline")!!.toLong())
                        .putInt("total", call.argument<Number>("total")!!.toInt())
                        .putString("label", call.argument<String>("label"))
                        .putString("soundUri", call.argument<String>("soundUri"))
                        .putBoolean("sound", call.argument<Boolean>("sound") == true)
                        .putBoolean("vibrate", call.argument<Boolean>("vibrate") == true)
                        .putBoolean("paused", false).putBoolean("finished", false).apply()
                    RestTimerService.start(this)
                    requestTimerNotifications()
                    result.success(null)
                }
                "pauseRest" -> {
                    preferences.edit().putBoolean("paused", true).putBoolean("finished", false)
                        .putInt("remaining", call.argument<Number>("remaining")!!.toInt())
                        .putInt("total", call.argument<Number>("total")!!.toInt())
                        .putString("label", call.argument<String>("label"))
                        .putString("soundUri", call.argument<String>("soundUri"))
                        .putBoolean("sound", call.argument<Boolean>("sound") == true)
                        .putBoolean("vibrate", call.argument<Boolean>("vibrate") == true).apply()
                    RestTimerService.stop(this, clear = false)
                    result.success(null)
                }
                "cancelRest" -> {
                    RestTimerService.stop(this)
                    result.success(null)
                }
                "getRest" -> {
                    val deadline = preferences.getLong("deadline", 0)
                    val paused = preferences.getBoolean("paused", false)
                    val finished = preferences.getBoolean("finished", false) || (!paused && deadline > 0 && deadline <= System.currentTimeMillis())
                    if (finished || (deadline <= 0 && !paused)) result.success(null)
                    else {
                        if (!paused && !finished) RestTimerService.start(this)
                        result.success(mapOf("deadline" to deadline, "total" to preferences.getInt("total", 60),
                            "remaining" to preferences.getInt("remaining", 0), "paused" to paused, "finished" to finished,
                            "label" to preferences.getString("label", "Rest"), "sound" to preferences.getBoolean("sound", true),
                            "vibrate" to preferences.getBoolean("vibrate", false), "soundUri" to preferences.getString("soundUri", null)))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        restListener?.let(preferences::unregisterOnSharedPreferenceChangeListener)
        restListener = null
        restEvents?.setStreamHandler(null)
        restEvents = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        stopSoundPreview()
        pendingSound?.success(null)
        pendingSound = null
        super.onDestroy()
    }

    private fun stopSoundPreview() {
        restSound.stop()
        pendingPreview?.success(null)
        pendingPreview = null
    }

    private fun requestTimerNotifications() {
        val consent = getSharedPreferences("fitnotes_permissions", MODE_PRIVATE)
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
            && !consent.getBoolean("notifications_requested", false)) {
            consent.edit().putBoolean("notifications_requested", true).apply()
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 72)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 73) {
            val result = pendingSound ?: return
            pendingSound = null
            if (resultCode != Activity.RESULT_OK) { result.success(null); return }
            @Suppress("DEPRECATION")
            val uri = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            if (uri == null) { result.success(null); return }
            if ((data?.flags ?: 0) and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0) {
                try { contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (_: SecurityException) { }
            }
            result.success(uri.toString())
            return
        }
        if (requestCode != 71) return
        val result = pendingSave ?: return
        val bytes = pendingBytes
        pendingSave = null
        pendingBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) { result.success(false); return }
        Thread {
            try {
                val stream = contentResolver.openOutputStream(uri) ?: error("Cannot open the selected file.")
                stream.use { it.write(bytes) }
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread { result.error("save_failed", error.message, null) }
            }
        }.start()
    }
}
