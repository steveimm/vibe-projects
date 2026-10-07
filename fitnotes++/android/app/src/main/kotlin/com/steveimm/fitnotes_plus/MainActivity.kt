package com.steveimm.fitnotes_plus

import android.app.Activity
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "fitnotes/device"
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private val handler = Handler(Looper.getMainLooper())
    private var timerAction: Runnable? = null
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
                    timerAction?.let(handler::removeCallbacks)
                    val deadline = call.argument<Number>("deadline")!!.toLong()
                    val sound = call.argument<Boolean>("sound") == true
                    val vibrate = call.argument<Boolean>("vibrate") == true
                    preferences.edit().putLong("deadline", deadline)
                        .putInt("total", call.argument<Number>("total")!!.toInt())
                        .putString("label", call.argument<String>("label"))
                        .putBoolean("sound", sound).putBoolean("vibrate", vibrate).apply()
                    scheduleAlert(deadline, sound, vibrate)
                    result.success(null)
                }
                "cancelRest" -> {
                    timerAction?.let(handler::removeCallbacks)
                    preferences.edit().clear().apply()
                    result.success(null)
                }
                "getRest" -> {
                    val deadline = preferences.getLong("deadline", 0)
                    if (deadline <= System.currentTimeMillis()) result.success(null)
                    else {
                        val sound = preferences.getBoolean("sound", true)
                        val vibrate = preferences.getBoolean("vibrate", false)
                        scheduleAlert(deadline, sound, vibrate)
                        result.success(mapOf("deadline" to deadline, "total" to preferences.getInt("total", 60),
                            "label" to preferences.getString("label", "Rest"), "sound" to sound, "vibrate" to vibrate))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scheduleAlert(deadline: Long, sound: Boolean, vibrate: Boolean) {
        timerAction?.let(handler::removeCallbacks)
        timerAction = Runnable {
            if (sound) {
                try {
                    val tone = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 75)
                    tone.startTone(ToneGenerator.TONE_PROP_ACK, 600)
                    handler.postDelayed({ tone.release() }, 900)
                } catch (_: RuntimeException) { }
            }
            if (vibrate) {
                val vibrator = getSystemService(VIBRATOR_SERVICE) as Vibrator
                if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
                else @Suppress("DEPRECATION") vibrator.vibrate(500)
            }
            preferences.edit().clear().apply()
        }
        handler.postDelayed(timerAction!!, (deadline - System.currentTimeMillis()).coerceAtLeast(0))
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
