package id.steveimm.pocketpilot.platform

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.os.Build
import android.util.Log
import android.view.Display
import id.steveimm.pocketpilot.model.ScreenImage
import id.steveimm.pocketpilot.model.ScreenImageSource
import id.steveimm.pocketpilot.perception.screenshotJpegQuality
import id.steveimm.pocketpilot.perception.screenshotMaxDimension
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.trace.TraceRecorder
import java.io.File
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Captures an unobstructed screen, compresses it, and persists optional local diagnostics. */
class AccessibilityScreenshotCapturer(
        private val service: AccessibilityService,
        private val config: SessionConfig,
        private val traceRecorder: TraceRecorder,
        private val overlayGate: OverlayTouchGate? = null,
) {
    companion object {
        private const val TAG = "A11yScreenshotCapturer"
        private const val SCREENSHOT_TIMEOUT_MS = 5_000L
        private const val MAX_DEBUG_SCREENSHOTS = 20
    }

    data class ScreenshotCapture(val image: ScreenImage, val tracePath: String?)

    suspend fun capture(): ScreenshotCapture? {
        if (!isScreenAvailable(service)) return null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return null
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val windowCapture = try { WindowScreenshotComposer(service).capture() }
            catch (e: CancellationException) { throw e }
            catch (e: Exception) {
                Log.w(TAG, "Window capture unavailable", e)
                null
            }
            if (windowCapture?.protectedContent == true) return null
            windowCapture?.bitmap?.let { bitmap ->
                try { return compressBitmap(bitmap) } finally { bitmap.recycle() }
            }
        }
        Log.d(TAG, "Using display screenshot fallback")
        var captured: AccessibilityService.ScreenshotResult? = null
        try {
            withContext(Dispatchers.Main) {
                overlayGate?.beginScreenshotCapture().use {
                    if (overlayGate != null) delay(80)
                    captured = takeDisplayScreenshot()
                }
            }
            return captured?.let { compressScreenshot(it) }
        } finally {
            captured?.hardwareBuffer?.close()
        }
    }

    private suspend fun takeDisplayScreenshot(): AccessibilityService.ScreenshotResult? = boundedCallback(
        timeoutMs = SCREENSHOT_TIMEOUT_MS,
        label = "takeScreenshot",
    ) { cont ->
        service.takeScreenshot(Display.DEFAULT_DISPLAY, service.mainExecutor, object : AccessibilityService.TakeScreenshotCallback {
            override fun onSuccess(screenshot: AccessibilityService.ScreenshotResult) {
                cont.resume(screenshot) { _, value, _ -> value.hardwareBuffer.close() }
            }
            override fun onFailure(errorCode: Int) {
                Log.w(TAG, "takeScreenshot failed: ${formatScreenshotError(errorCode)}")
                cont.resume(null)
            }
        })
    }

    private suspend fun compressScreenshot(screenshot: AccessibilityService.ScreenshotResult): ScreenshotCapture? {
        return withContext(Dispatchers.Default) {
            val hardware = Bitmap.wrapHardwareBuffer(screenshot.hardwareBuffer, screenshot.colorSpace) ?: return@withContext null
            val bitmap = try { hardware.copy(Bitmap.Config.ARGB_8888, false) } finally { hardware.recycle() } ?: return@withContext null
            try { compressBitmap(bitmap) } finally { bitmap.recycle() }
        }
    }

    private suspend fun compressBitmap(bitmap: Bitmap): ScreenshotCapture? = withContext(Dispatchers.Default) {
        if (!isScreenAvailable(service)) return@withContext null
        val scaled = BitmapUtils.scaleBitmapIfNeeded(bitmap, config.perceptionConfig.screenshotMaxDimension)
        try {
            val bytes = BitmapUtils.compressJpeg(scaled, config.perceptionConfig.screenshotJpegQuality) ?: return@withContext null
            if (config.debugMode) persistDebugScreenshot(bytes, scaled.width, scaled.height)
            val tracePath = if (traceRecorder.enabled) traceRecorder.storeBytes(
                kind = "screenshot",
                filenameHint = "screenshot_${System.currentTimeMillis()}_${scaled.width}x${scaled.height}.jpg",
                bytes = bytes,
                mimeType = "image/jpeg",
            )?.path else null
            ScreenshotCapture(ScreenImage(scaled.width, scaled.height, "image/jpeg", bytes, ScreenImageSource.ACCESSIBILITY_SCREENSHOT), tracePath)
        } finally {
            if (scaled !== bitmap) scaled.recycle()
        }
    }

    private fun persistDebugScreenshot(bytes: ByteArray, width: Int, height: Int) {
        val dir = service.getExternalFilesDir("debug-output") ?: return
        if (!dir.exists() && !dir.mkdirs()) {
            Log.w(TAG, "Failed to create debug-output directory")
            return
        }
        // Enforce retention limit to match VD path
        val files = dir.listFiles { _, name -> name.startsWith("llm_screenshot_") }
        if (files != null && files.size >= MAX_DEBUG_SCREENSHOTS) {
            files.sortBy { it.lastModified() }
            for (i in 0..(files.size - MAX_DEBUG_SCREENSHOTS)) {
                files[i].delete()
            }
        }
        val filename = "llm_screenshot_${System.currentTimeMillis()}_${width}x${height}.jpg"
        val file = File(dir, filename)
        try {
            file.outputStream().use { it.write(bytes) }
            Log.d(TAG, "Saved LLM screenshot: ${file.absolutePath}")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to save LLM screenshot: ${e.message}")
        }
    }

    private fun formatScreenshotError(errorCode: Int): String {
        return when (errorCode) {
            AccessibilityService.ERROR_TAKE_SCREENSHOT_INTERVAL_TIME_SHORT -> "interval too short"
            AccessibilityService.ERROR_TAKE_SCREENSHOT_INTERNAL_ERROR -> "internal error"
            AccessibilityService.ERROR_TAKE_SCREENSHOT_SECURE_WINDOW -> "secure window"
            else -> "error code $errorCode"
        }
    }
}
