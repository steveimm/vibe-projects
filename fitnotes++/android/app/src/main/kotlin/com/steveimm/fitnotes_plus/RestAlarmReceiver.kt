package com.steveimm.fitnotes_plus

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager

class RestAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED) {
            if (canSchedule(context)) {
                context.getSharedPreferences("fitnotes_permissions", Context.MODE_PRIVATE).edit()
                    .putBoolean("rest_alarm_allowed", true).apply()
                schedule(context)
            }
            return
        }
        val saved = context.getSharedPreferences("fitnotes_timer", Context.MODE_PRIVATE)
        val deadline = intent.getLongExtra("deadline", 0)
        if (intent.action != EXPIRE || deadline <= 0 || saved.getLong("deadline", 0) != deadline ||
            saved.getBoolean("paused", false) || saved.getBoolean("finished", false)) return
        releaseDeliveryLock()
        deliveryLock = (context.getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "FitNotes:rest-delivery").apply { acquire(10_000) }
        try {
            RestTimerService.start(context, deadline)
        } catch (error: RuntimeException) {
            releaseDeliveryLock()
            throw error
        }
    }

    companion object {
        const val EXPIRE = "com.steveimm.fitnotes_plus.REST_EXPIRED"
        private var deliveryLock: PowerManager.WakeLock? = null

        fun canSchedule(context: Context): Boolean = Build.VERSION.SDK_INT < 31 ||
            context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

        fun showIntent(context: Context): PendingIntent = PendingIntent.getActivity(context, 1,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        fun schedule(context: Context): Boolean {
            val saved = context.getSharedPreferences("fitnotes_timer", Context.MODE_PRIVATE)
            val deadline = saved.getLong("deadline", 0)
            if (deadline <= 0 || saved.getBoolean("paused", false) || saved.getBoolean("finished", false) || !canSchedule(context)) {
                cancel(context)
                return false
            }
            val operation = PendingIntent.getBroadcast(context, 3,
                Intent(context, RestAlarmReceiver::class.java).setAction(EXPIRE)
                    .addFlags(Intent.FLAG_RECEIVER_FOREGROUND).putExtra("deadline", deadline),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            return try {
                // Idle-allowed alarms are rate limited, which can delay consecutive short rests.
                context.getSystemService(AlarmManager::class.java)
                    .setAlarmClock(AlarmManager.AlarmClockInfo(deadline, showIntent(context)), operation)
                true
            } catch (_: SecurityException) {
                false
            }
        }

        fun cancel(context: Context) {
            val operation = PendingIntent.getBroadcast(context, 3,
                Intent(context, RestAlarmReceiver::class.java).setAction(EXPIRE),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE) ?: return
            context.getSystemService(AlarmManager::class.java).cancel(operation)
            operation.cancel()
        }

        fun releaseDeliveryLock() {
            if (deliveryLock?.isHeld == true) deliveryLock?.release()
            deliveryLock = null
        }
    }
}
