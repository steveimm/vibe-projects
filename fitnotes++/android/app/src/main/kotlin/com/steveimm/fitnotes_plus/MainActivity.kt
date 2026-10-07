package com.steveimm.fitnotes_plus

import android.Manifest
import android.content.pm.PackageManager
import android.app.Activity
import android.content.Intent
import android.os.Build
import android.net.Uri
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "fitnotes/device"
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private val preferences by lazy { getSharedPreferences("fitnotes_timer", MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                "scheduleRest" -> {
                    preferences.edit().putLong("deadline", call.argument<Number>("deadline")!!.toLong())
                        .putInt("total", call.argument<Number>("total")!!.toInt())
                        .putString("label", call.argument<String>("label"))
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
                    if (deadline <= 0 && !paused && !finished) result.success(null)
                    else {
                        if (!paused && !finished) RestTimerService.start(this)
                        result.success(mapOf("deadline" to deadline, "total" to preferences.getInt("total", 60),
                            "remaining" to preferences.getInt("remaining", 0), "paused" to paused, "finished" to finished,
                            "label" to preferences.getString("label", "Rest"), "sound" to preferences.getBoolean("sound", true),
                            "vibrate" to preferences.getBoolean("vibrate", false)))
                    }
                }
                else -> result.notImplemented()
            }
        }
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
