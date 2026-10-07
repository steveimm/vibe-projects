package com.steveimm.fitnotes_plus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator

class RestTimerService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val preferences by lazy { getSharedPreferences("fitnotes_timer", MODE_PRIVATE) }
    private val notifications by lazy { getSystemService(NotificationManager::class.java) }
    private var wakeLock: PowerManager.WakeLock? = null
    private var alert: Runnable? = null
    private var finish: Runnable? = null
    private var tone: ToneGenerator? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) {
            preferences.edit().clear().apply()
            notifications.cancel(COMPLETE_ID)
            stopSelf()
            return START_NOT_STICKY
        }
        val deadline = preferences.getLong("deadline", 0)
        if (deadline <= 0 || preferences.getBoolean("paused", false) || preferences.getBoolean("finished", false)) { stopSelf(); return START_NOT_STICKY }
        alert?.let(handler::removeCallbacks)
        finish?.let(handler::removeCallbacks)
        tone?.release()
        tone = null
        if (Build.VERSION.SDK_INT >= 26) {
            notifications.createNotificationChannel(NotificationChannel(CHANNEL, "Workout rest timer", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Countdown and completion alerts for your rest timer"
                setSound(null, null)
                enableVibration(false)
            })
        }
        val notification = notificationBuilder()
            .setContentTitle("Rest timer")
            .setContentText(preferences.getString("label", "FitNotes++"))
            .setWhen(deadline).setUsesChronometer(true).setChronometerCountDown(true)
            .setOngoing(true).setOnlyAlertOnce(true)
            .addAction(Notification.Action.Builder(null, "Stop", PendingIntent.getService(this, 2,
                Intent(this, RestTimerService::class.java).setAction(STOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)).build())
            .build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(ONGOING_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(ONGOING_ID, notification)
        notifications.cancel(COMPLETE_ID)
        if (wakeLock?.isHeld == true) wakeLock?.release()
        val remaining = (deadline - System.currentTimeMillis()).coerceIn(0, 3_600_000)
        wakeLock = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "FitNotes:rest").apply {
            acquire(remaining + 5000)
        }
        alert = Runnable { complete() }
        handler.postDelayed(alert!!, remaining)
        return START_STICKY
    }

    @Suppress("DEPRECATION")
    private fun notificationBuilder(): Notification.Builder {
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        return builder.setSmallIcon(R.drawable.app_symbol).setColor(0xFF326A59.toInt())
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setContentIntent(PendingIntent.getActivity(this, 1, Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
    }

    @Suppress("DEPRECATION")
    private fun complete() {
        preferences.edit().putBoolean("finished", true).apply()
        if (preferences.getBoolean("sound", true)) {
            try {
                tone = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 75)
                tone?.startTone(ToneGenerator.TONE_PROP_ACK, 700)
            } catch (_: RuntimeException) { }
        }
        if (preferences.getBoolean("vibrate", false)) {
            val vibrator = getSystemService(VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
            else vibrator.vibrate(500)
        }
        if (notifications.areNotificationsEnabled()) {
            notifications.notify(COMPLETE_ID, notificationBuilder().setContentTitle("Rest complete")
                .setContentText(preferences.getString("label", "Ready for your next set"))
                .setAutoCancel(true).setShowWhen(false).build())
        }
        finish = Runnable { stopSelf() }
        handler.postDelayed(finish!!, 1000)
    }

    override fun onDestroy() {
        alert?.let(handler::removeCallbacks)
        finish?.let(handler::removeCallbacks)
        tone?.release()
        if (wakeLock?.isHeld == true) wakeLock?.release()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "fitnotes_rest"
        private const val ONGOING_ID = 3101
        private const val COMPLETE_ID = 3102
        private const val STOP = "fitnotes.stop_rest"

        fun start(context: Context) {
            val intent = Intent(context, RestTimerService::class.java)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
        }
        fun stop(context: Context, clear: Boolean = true) {
            context.stopService(Intent(context, RestTimerService::class.java))
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.cancel(ONGOING_ID)
            manager.cancel(COMPLETE_ID)
            if (clear) context.getSharedPreferences("fitnotes_timer", Context.MODE_PRIVATE).edit().clear().apply()
        }
    }
}
