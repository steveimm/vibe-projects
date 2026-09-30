package id.steveimm.pocketpilot.platform

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import androidx.core.content.ContextCompat

internal fun isScreenAvailable(context: Context): Boolean =
    context.getSystemService(PowerManager::class.java).isInteractive &&
        !context.getSystemService(KeyguardManager::class.java).isKeyguardLocked

internal class DeviceScreenState(private val context: Context, private val onChanged: (Boolean) -> Unit) {
    private var registered = false
    private var available: Boolean? = null
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) { refresh(screenOff = intent.action == Intent.ACTION_SCREEN_OFF) }
    }

    fun start() {
        if (!registered) {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_USER_PRESENT)
            }
            ContextCompat.registerReceiver(context, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
            registered = true
        }
        refresh()
    }

    fun refresh(screenOff: Boolean = false) {
        val next = !screenOff && isScreenAvailable(context)
        if (next != available) { available = next; onChanged(next) }
    }

    fun stop() {
        if (registered) context.unregisterReceiver(receiver)
        registered = false
    }
}
