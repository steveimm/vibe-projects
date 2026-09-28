package id.steveimm.pocketpilot.platform.virtualdisplay

import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import java.util.concurrent.atomic.AtomicInteger
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.InternalCoroutinesApi
import kotlinx.coroutines.suspendCancellableCoroutine
import org.lsposed.hiddenapibypass.HiddenApiBypass
import rikka.shizuku.Shizuku

/** Outcome of a single inline Shizuku permission request. */
internal sealed interface PermissionRequestResult {
        data object Granted : PermissionRequestResult
        data object Denied : PermissionRequestResult
        data object Error : PermissionRequestResult
}

/** Runtime-level Shizuku operations: availability, permissions, binder lifecycle, hidden API. */
internal class ShizukuRuntimeGateway {
        companion object {
                private const val TAG = "ShizukuRuntime"

                /** Per-process counter for permission request codes. Each call gets a unique code so a stale listener from a prior
                 * cancelled request never matches a new request's grant result. */
                private val requestCodeSeed = AtomicInteger(2000)
        }

        fun isAvailable(): Boolean {
                return try {
                        Shizuku.pingBinder()
                } catch (e: Exception) {
                        Log.w(TAG, "Shizuku ping failed: ${e.message}")
                        false
                }
        }

        fun hasPermission(): Boolean {
                return try {
                        Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
                } catch (e: Exception) {
                        Log.w(TAG, "Shizuku permission check failed: ${e.message}")
                        false
                }
        }

        fun requestPermission(requestCode: Int) {
                Shizuku.requestPermission(requestCode)
        }

        /** Request Shizuku permission and suspend until the user responds. */
        @OptIn(InternalCoroutinesApi::class)
        suspend fun requestPermissionAndAwait(): PermissionRequestResult {
                val reqCode = requestCodeSeed.getAndIncrement()
                return try {
                        suspendCancellableCoroutine { cont ->
                                val listener = object : Shizuku.OnRequestPermissionResultListener {
                                        override fun onRequestPermissionResult(
                                                requestCode: Int,
                                                grantResult: Int,
                                        ) {
                                                if (requestCode != reqCode) return
                                                Shizuku.removeRequestPermissionResultListener(this)
                                                val result =
                                                        if (grantResult ==
                                                                PackageManager.PERMISSION_GRANTED
                                                        ) {
                                                                PermissionRequestResult.Granted
                                                        } else {
                                                                PermissionRequestResult.Denied
                                                        }
                                                val token = cont.tryResume(result)
                                                if (token != null) cont.completeResume(token)
                                        }
                                }
                                Shizuku.addRequestPermissionResultListener(listener)
                                cont.invokeOnCancellation {
                                        Shizuku.removeRequestPermissionResultListener(listener)
                                }
                                try {
                                        Shizuku.requestPermission(reqCode)
                                } catch (e: Exception) {
                                        Log.w(TAG, "Shizuku.requestPermission threw: ${e.message}")
                                        Shizuku.removeRequestPermissionResultListener(listener)
                                        val token = cont.tryResume(PermissionRequestResult.Error)
                                        if (token != null) cont.completeResume(token)
                                }
                        }
                } catch (e: CancellationException) {
                        throw e
                } catch (e: Exception) {
                        Log.w(TAG, "Shizuku permission request failed: ${e.message}")
                        PermissionRequestResult.Error
                }
        }

        fun addBinderDeadListener(listener: Shizuku.OnBinderDeadListener) {
                Shizuku.addBinderDeadListener(listener)
        }

        fun removeBinderDeadListener(listener: Shizuku.OnBinderDeadListener) {
                Shizuku.removeBinderDeadListener(listener)
        }

        fun addRequestPermissionResultListener(
                listener: Shizuku.OnRequestPermissionResultListener
        ) {
                Shizuku.addRequestPermissionResultListener(listener)
        }

        fun removeRequestPermissionResultListener(
                listener: Shizuku.OnRequestPermissionResultListener
        ) {
                Shizuku.removeRequestPermissionResultListener(listener)
        }

        fun bypassHiddenApis() {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        HiddenApiBypass.addHiddenApiExemptions("")
                        Log.d(TAG, "Hidden API restrictions bypassed")
                }
        }
}
