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
import kotlinx.coroutines.delay
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Accessibility screenshot capture pipeline: 1) a11y screenshot API (bounded — never waits forever) 2) software bitmap conversion 3)
 * scale + jpeg compression 4) optional debug/trace persistence */
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
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return null
        }

        val result = withContext(Dispatchers.Main) {
            overlayGate?.beginScreenshotCapture().use {
                if (overlayGate != null) delay(80)
                takeDisplayScreenshot()
            }
        } ?: return null
        return compressScreenshot(result)
    }

    private suspend fun takeDisplayScreenshot(): AccessibilityService.ScreenshotResult? {
        return withContext(Dispatchers.Main) {
            boundedCallback(
                timeoutMs = SCREENSHOT_TIMEOUT_MS,
                label = "takeScreenshot"
            ) { cont ->
                service.takeScreenshot(
                        Display.DEFAULT_DISPLAY,
                        service.mainExecutor,
                        object : AccessibilityService.TakeScreenshotCallback {
                            override fun onSuccess(
                                    screenshot: AccessibilityService.ScreenshotResult
                            ) {
                                cont.resume(screenshot) { _, value, _ -> value.hardwareBuffer.close() }
                            }

                            override fun onFailure(errorCode: Int) {
                                Log.w(
                                        TAG,
                                        "takeScreenshot failed: ${formatScreenshotError(errorCode)}"
                                )
                                cont.resume(null)
                            }
                        }
                )
            }
        }
    }

    private suspend fun compressScreenshot(
            screenshot: AccessibilityService.ScreenshotResult
    ): ScreenshotCapture? =
            withContext(Dispatchers.Default) {
                val hardwareBuffer = screenshot.hardwareBuffer
                var softwareBitmap: Bitmap? = null
                var scaledBitmap: Bitmap? = null
                try {
                    val hardwareBitmap =
                            Bitmap.wrapHardwareBuffer(hardwareBuffer, screenshot.colorSpace)
                                    ?: return@withContext null

                    softwareBitmap = try {
                        hardwareBitmap.copy(Bitmap.Config.ARGB_8888, false)
                    } finally {
                        hardwareBitmap.recycle()
                    }
                    if (softwareBitmap == null) {
                        return@withContext null
                    }

                    scaledBitmap =
                            BitmapUtils.scaleBitmapIfNeeded(
                                    softwareBitmap,
                                    config.perceptionConfig.screenshotMaxDimension
                            )
                    val width = scaledBitmap.width
                    val height = scaledBitmap.height
                    val jpegBytes =
                            BitmapUtils.compressJpeg(
                                    scaledBitmap,
                                    config.perceptionConfig.screenshotJpegQuality
                            )

                    jpegBytes?.let { bytes ->
                        if (config.debugMode) {
                            persistDebugScreenshot(bytes, width, height)
                        }
                        val tracePath =
                                if (traceRecorder.enabled) {
                                    traceRecorder.storeBytes(
                                                    kind = "screenshot",
                                                    filenameHint =
                                                            "screenshot_${System.currentTimeMillis()}_${width}x${height}.jpg",
                                                    bytes = bytes,
                                                    mimeType = "image/jpeg"
                                            )
                                            ?.path
                                } else {
                                    null
                                }
                        val image =
                                ScreenImage(
                                        width = width,
                                        height = height,
                                        mimeType = "image/jpeg",
                                        bytes = bytes,
                                        source = ScreenImageSource.ACCESSIBILITY_SCREENSHOT
                                )
                        ScreenshotCapture(image = image, tracePath = tracePath)
                    }
                } finally {
                    scaledBitmap?.let { s ->
                        if (s !== softwareBitmap) s.recycle()
                    }
                    softwareBitmap?.recycle()
                    hardwareBuffer.close()
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
