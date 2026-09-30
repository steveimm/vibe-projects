package id.steveimm.pocketpilot.platform

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.os.Build
import android.util.Log
import android.view.WindowInsets
import android.view.WindowManager
import android.view.accessibility.AccessibilityWindowInfo
import androidx.annotation.RequiresApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume
import id.steveimm.pocketpilot.util.recycleCompat

/** Compose visible window surfaces in display coordinates, excluding accessibility overlays. */
@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
internal class WindowScreenshotComposer(private val service: AccessibilityService) {
    private data class Window(val id: Int, val layer: Int, val type: Int, val bounds: Rect, val rootBounds: Rect?)
    private data class Capture(val result: AccessibilityService.ScreenshotResult? = null, val error: Int? = null)
    data class Result(val bitmap: Bitmap? = null, val protectedContent: Boolean = false)

    suspend fun capture(): Result {
        var bitmap: Bitmap? = null
        var delivered = false
        try {
            val result = withContext(Dispatchers.Main) {
                if (service.magnificationController.scale > 1f) return@withContext Result()
                val metrics = service.getSystemService(WindowManager::class.java).maximumWindowMetrics
                val display = metrics.bounds
                val windows = windows()
                val insets = metrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars())
                val content = Rect(display.left + insets.left, display.top + insets.top,
                    display.right - insets.right, display.bottom - insets.bottom)
                if (windows.any { it.type == AccessibilityWindowInfo.TYPE_SYSTEM && Rect.intersects(it.bounds, content) }) {
                    return@withContext Result()
                }
                if (windows.isEmpty()) return@withContext Result()
                val applications = windows.filter { it.type == AccessibilityWindowInfo.TYPE_APPLICATION }
                if (applications.indices.any { i -> applications.drop(i + 1).any { Rect.intersects(applications[i].bounds, it.bounds) } }) {
                    return@withContext Result()
                }
                val captures = mutableListOf<Capture>()
                try {
                    coroutineScope {
                        windows.map { window -> async { captureWindow(window.id).also { captures.add(it) } } }.awaitAll()
                    }.let { ordered ->
                        if (ordered.any { it.error == AccessibilityService.ERROR_TAKE_SCREENSHOT_SECURE_WINDOW }) {
                            return@withContext Result(protectedContent = true)
                        }
                        if (ordered.any { it.result == null } || windows != windows() ||
                            display != service.getSystemService(WindowManager::class.java).maximumWindowMetrics.bounds) {
                            return@withContext Result()
                        }
                        withContext(Dispatchers.Default) { compose(display, windows, ordered).also { bitmap = it.bitmap } }
                    }
                } finally {
                    captures.forEach { it.result?.hardwareBuffer?.close() }
                }
            }
            delivered = true
            return result
        } finally {
            if (!delivered) bitmap?.recycle()
        }
    }

    private fun windows(): List<Window> {
        val windows = service.windows ?: return emptyList()
        return try {
            windows.filter { it.type != AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY }
                .map { window ->
                    val root = window.root
                    val rootBounds = try { root?.let { Rect().also(it::getBoundsInScreen) } }
                        finally { root?.recycleCompat() }
                    Window(window.id, window.layer, window.type, Rect().also(window::getBoundsInScreen), rootBounds)
                }
                .filter { !it.bounds.isEmpty }
                .sortedBy { it.layer }
        } finally {
            @Suppress("DEPRECATION")
            windows.forEach { it.recycle() }
        }
    }

    private suspend fun captureWindow(id: Int): Capture {
        suspend fun request(): Capture = boundedCallback<Capture>(5_000, "window screenshot") { continuation ->
            service.takeScreenshotOfWindow(id, service.mainExecutor, object : AccessibilityService.TakeScreenshotCallback {
                override fun onSuccess(screenshot: AccessibilityService.ScreenshotResult) {
                    continuation.resume(Capture(result = screenshot)) { _, value, _ -> value?.result?.hardwareBuffer?.close() }
                }
                override fun onFailure(errorCode: Int) { continuation.resume(Capture(error = errorCode)) }
            })
        } ?: Capture()
        val first = request()
        if (first.error != AccessibilityService.ERROR_TAKE_SCREENSHOT_INTERVAL_TIME_SHORT) return first
        delay(350)
        return request()
    }

    private fun compose(display: Rect, windows: List<Window>, captures: List<Capture>): Result {
        val output = Bitmap.createBitmap(display.width(), display.height(), Bitmap.Config.ARGB_8888)
        var retained = false
        try {
            val canvas = Canvas(output)
            canvas.drawColor(Color.TRANSPARENT)
            windows.zip(captures).forEach { (window, capture) ->
                val screenshot = capture.result ?: return Result()
                val buffer = screenshot.hardwareBuffer
                Log.d("WindowScreenshot", "id=${window.id} type=${window.type} layer=${window.layer} bounds=${window.bounds} buffer=${buffer.width}x${buffer.height}")
                val candidates = listOfNotNull(window.bounds, window.rootBounds).distinct().filter {
                    buffer.width == it.width() && buffer.height == it.height() && display.contains(it)
                }
                val bounds = candidates.singleOrNull() ?: return Result()
                val hardware = Bitmap.wrapHardwareBuffer(buffer, screenshot.colorSpace) ?: return Result()
                val software = try { hardware.copy(Bitmap.Config.ARGB_8888, false) } finally { hardware.recycle() }
                    ?: return Result()
                try { canvas.drawBitmap(software, bounds.left.toFloat(), bounds.top.toFloat(), null) }
                finally { software.recycle() }
            }
            val row = IntArray(output.width)
            for (y in 0 until output.height) {
                output.getPixels(row, 0, output.width, 0, y, output.width, 1)
                if (row.any { (it ushr 24) < 255 }) {
                    Log.d("WindowScreenshot", "Incomplete coverage; using display capture")
                    return Result()
                }
            }
            retained = true
            Log.d("WindowScreenshot", "Captured ${windows.size} windows without hiding overlays")
            return Result(bitmap = output)
        } finally {
            if (!retained) output.recycle()
        }
    }
}
