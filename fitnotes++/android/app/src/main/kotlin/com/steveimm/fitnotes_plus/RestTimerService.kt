package com.steveimm.fitnotes_plus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
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
    private var countdown: Runnable? = null
    private var finish: Runnable? = null
    private var completed = false
    private val sound by lazy { RestAlertPlayer(this) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) {
            RestAlarmReceiver.cancel(this)
            RestAlarmReceiver.releaseDeliveryLock()
            clearSavedTimer(this)
            completed = false
            stopCallbacks()
            stopForeground(STOP_FOREGROUND_REMOVE)
            notifications.cancel(ONGOING_ID)
            notifications.cancel(COMPLETE_ID)
            stopSelf()
            return START_NOT_STICKY
        }
        val deadline = preferences.getLong("deadline", 0)
        if (intent?.action == RestAlarmReceiver.EXPIRE &&
            (intent.getLongExtra("deadline", 0) != deadline || !isCurrent(deadline))) {
            RestAlarmReceiver.releaseDeliveryLock()
            if (!isCurrent(deadline) && !completed) stopSelf()
            return if (isCurrent(deadline)) START_STICKY else START_NOT_STICKY
        }
        if (deadline <= 0 || preferences.getBoolean("paused", false) || preferences.getBoolean("finished", false)) { stopSelf(); return START_NOT_STICKY }
        stopCallbacks()
        completed = false
        if (Build.VERSION.SDK_INT >= 26) {
            val previous = notifications.getNotificationChannel("fitnotes_rest")
            val importance = if (previous != null && (Build.VERSION.SDK_INT < 29 || previous.hasUserSetImportance()))
                previous.importance else NotificationManager.IMPORTANCE_DEFAULT
            notifications.createNotificationChannel(NotificationChannel(CHANNEL, "Rest countdown", importance).apply {
                description = "Time remaining during rest"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                if (previous != null) lockscreenVisibility = previous.lockscreenVisibility
            })
        }
        val builder = notificationBuilder()
            .setContentTitle("Rest timer")
            .setContentText(remainingText(deadline)).setShowWhen(false)
            .setOngoing(true).setOnlyAlertOnce(true)
            .addAction(Notification.Action.Builder(null, "Cancel", PendingIntent.getService(this, 2,
                Intent(this, RestTimerService::class.java).setAction(STOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)).build())
        val notification = builder.build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(ONGOING_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(ONGOING_ID, notification)
        notifications.cancel(COMPLETE_ID)
        if (wakeLock?.isHeld == true) wakeLock?.release()
        wakeLock = null
        val remaining = (deadline - System.currentTimeMillis()).coerceIn(0, 3_600_000)
        if (remaining == 0L) {
            complete(deadline)
            return START_NOT_STICKY
        }
        RestAlarmReceiver.schedule(this)
        RestAlarmReceiver.releaseDeliveryLock()
        alert = object : Runnable {
            override fun run() {
                if (!isCurrent(deadline)) return
                val left = deadline - System.currentTimeMillis()
                if (left > 0) handler.postDelayed(this, left) else complete(deadline)
            }
        }
        handler.postDelayed(alert!!, remaining)
        countdown = object : Runnable {
            override fun run() {
                val left = deadline - System.currentTimeMillis()
                if (completed || left <= 0 || !isCurrent(deadline)) return
                notifications.notify(ONGOING_ID, builder.setContentText(remainingText(deadline)).build())
                handler.postDelayed(this, minOf(1000L, left))
            }
        }
        handler.postDelayed(countdown!!, minOf(1000L, remaining))
        return START_STICKY
    }

    private fun isCurrent(deadline: Long): Boolean = deadline > 0 && preferences.getLong("deadline", 0) == deadline &&
        !preferences.getBoolean("paused", false) && !preferences.getBoolean("finished", false)

    private fun remainingText(deadline: Long): String {
        val seconds = ((deadline - System.currentTimeMillis() + 999) / 1000).coerceAtLeast(0)
        val minutes = seconds / 60
        val clock = "${minutes % 60}:${(seconds % 60).toString().padStart(2, '0')}"
        return if (minutes >= 60) "${minutes / 60}:${clock.padStart(5, '0')}" else clock
    }

    @Suppress("DEPRECATION")
    private fun notificationBuilder(channel: String = CHANNEL): Notification.Builder {
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel) else Notification.Builder(this)
        return builder.setSmallIcon(R.drawable.app_symbol).setColor(0xFF326A59.toInt())
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(RestAlarmReceiver.showIntent(this))
    }

    @Suppress("DEPRECATION")
    private fun complete(deadline: Long) {
        if (completed || !isCurrent(deadline) || System.currentTimeMillis() < deadline) return
        wakeLock = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "FitNotes:rest-alert").apply {
            acquire(RestAlertPlayer.MAX_DURATION_MS + 2000)
        }
        RestAlarmReceiver.releaseDeliveryLock()
        RestAlarmReceiver.cancel(this)
        val playSound = preferences.getBoolean("sound", true)
        val vibrate = preferences.getBoolean("vibrate", false)
        val soundUri = preferences.getString("soundUri", null)
        countdown?.let(handler::removeCallbacks)
        completed = true
        clearSavedTimer(this)
        if (vibrate) {
            val vibrator = getSystemService(VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
            else vibrator.vibrate(500)
        }
        if (notifications.areNotificationsEnabled()) {
            if (Build.VERSION.SDK_INT >= 26) {
                notifications.createNotificationChannel(NotificationChannel(ALERT_CHANNEL, "Rest complete", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    setSound(null, null)
                    enableVibration(false)
                })
            }
            val completion = notificationBuilder(ALERT_CHANNEL).setContentTitle("Rest complete")
                .setAutoCancel(true).setShowWhen(false)
            if (Build.VERSION.SDK_INT >= 26) completion.setTimeoutAfter(8000)
            if (Build.VERSION.SDK_INT >= 34) startForeground(ONGOING_ID, completion.build(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            else startForeground(ONGOING_ID, completion.build())
        }
        finish = Runnable { stopSelf() }
        handler.postDelayed(finish!!, RestAlertPlayer.MAX_DURATION_MS + 1000)
        if (playSound) sound.play(soundUri) { stopSelf() }
        else handler.postDelayed(finish!!, if (vibrate) 500 else 0)

    }

    private fun stopCallbacks() {
        alert?.let(handler::removeCallbacks)
        countdown?.let(handler::removeCallbacks)
        finish?.let(handler::removeCallbacks)
        sound.stop()
    }

    override fun onDestroy() {
        stopCallbacks()
        if (Build.VERSION.SDK_INT < 26) notifications.cancel(COMPLETE_ID)
        if (wakeLock?.isHeld == true) wakeLock?.release()
        stopForeground(if (completed && Build.VERSION.SDK_INT >= 26) STOP_FOREGROUND_DETACH else STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "fitnotes_rest_countdown"
        private const val ALERT_CHANNEL = "fitnotes_rest_alerts"
        private const val ONGOING_ID = 3101
        private const val COMPLETE_ID = 3102
        private const val STOP = "fitnotes.stop_rest"

        private fun clearSavedTimer(context: Context) {
            val saved = context.getSharedPreferences("fitnotes_timer", Context.MODE_PRIVATE)
            // Removing keys also notifies listeners on Android versions where clear() does not.
            val edit = saved.edit()
            saved.all.keys.forEach(edit::remove)
            edit.apply()
        }

        fun start(context: Context, alarmDeadline: Long? = null) {
            val intent = Intent(context, RestTimerService::class.java)
            if (alarmDeadline != null) intent.setAction(RestAlarmReceiver.EXPIRE).putExtra("deadline", alarmDeadline)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
        }
        fun stop(context: Context, clear: Boolean = true) {
            RestAlarmReceiver.cancel(context)
            RestAlarmReceiver.releaseDeliveryLock()
            if (clear) clearSavedTimer(context)
            context.stopService(Intent(context, RestTimerService::class.java))
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.cancel(ONGOING_ID)
            manager.cancel(COMPLETE_ID)
        }
    }
}
