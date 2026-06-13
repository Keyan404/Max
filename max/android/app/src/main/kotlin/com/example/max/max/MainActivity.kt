package com.example.max.max

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.max/screen"
    private val REQUEST_CODE_MEDIA_PROJECTION = 2001

    private var projectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var screenCaptureIntentData: Intent? = null
    private var screenCaptureResultCode = 0

    private var pendingResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestScreenCapturePermission" -> {
                    pendingResult = result
                    requestScreenCapturePermission()
                }
                "captureScreen" -> {
                    pendingResult = result
                    captureScreen()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun requestScreenCapturePermission() {
        val manager = projectionManager
        if (manager != null && screenCaptureIntentData == null) {
            startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_CODE_MEDIA_PROJECTION)
        } else {
            pendingResult?.success(true)
            pendingResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_MEDIA_PROJECTION) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                screenCaptureResultCode = resultCode
                screenCaptureIntentData = data
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
        }
    }

    private fun captureScreen() {
        val data = screenCaptureIntentData
        val manager = projectionManager
        if (data == null || manager == null) {
            pendingResult?.error("PERMISSION_DENIED", "Screen capture permission not granted.", null)
            pendingResult = null
            return
        }

        // Initialize MediaProjection session
        try {
            mediaProjection = manager.getMediaProjection(screenCaptureResultCode, data)
            performScreenCapture()
        } catch (e: Exception) {
            pendingResult?.error("CAPTURE_FAILED", "Failed starting media projection session: ${e.message}", null)
            pendingResult = null
        }
    }

    private fun performScreenCapture() {
        val displayMetrics = resources.displayMetrics
        val width = displayMetrics.widthPixels
        val height = displayMetrics.heightPixels
        val density = displayMetrics.densityDpi

        // Format RGBA_8888 captures screen pixels raw
        val imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        
        val virtualDisplay = mediaProjection?.createVirtualDisplay(
            "ScreenCapture",
            width,
            height,
            density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader.surface,
            null,
            null
        )

        // Capture after a tiny delay to allow display initialization
        Handler(Looper.getMainLooper()).postDelayed({
            var image: Image? = null
            var bitmap: Bitmap? = null
            try {
                image = imageReader.acquireLatestImage()
                if (image != null) {
                    val planes = image.planes
                    val buffer = planes[0].buffer
                    val pixelStride = planes[0].pixelStride
                    val rowStride = planes[0].rowStride
                    val rowPadding = rowStride - pixelStride * width

                    // Copy pixels into bitmap
                    bitmap = Bitmap.createBitmap(
                        width + rowPadding / pixelStride,
                        height,
                        Bitmap.Config.ARGB_8888
                    )
                    bitmap.copyPixelsFromBuffer(buffer)

                    // Crop out padding if necessary
                    val croppedBitmap = Bitmap.createBitmap(bitmap, 0, 0, width, height)
                    
                    // Compress to JPG Base64
                    val stream = ByteArrayOutputStream()
                    croppedBitmap.compress(Bitmap.CompressFormat.JPEG, 75, stream)
                    val byteArray = stream.toByteArray()
                    val base64Image = Base64.encodeToString(byteArray, Base64.NO_WRAP)

                    pendingResult?.success(base64Image)
                } else {
                    pendingResult?.error("NO_IMAGE", "Could not acquire screen frame from ImageReader", null)
                }
            } catch (e: Exception) {
                pendingResult?.error("CAPTURE_FAILED", "Screen capture exception: ${e.message}", null)
            } finally {
                // Clean up display connections
                image?.close()
                bitmap?.recycle()
                virtualDisplay?.release()
                imageReader.close()
                mediaProjection?.stop()
                mediaProjection = null
                pendingResult = null
            }
        }, 300)
    }
}
