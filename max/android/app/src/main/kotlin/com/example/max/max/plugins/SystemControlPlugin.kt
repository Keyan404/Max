package com.example.max.max.plugins

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.example.max.max.services.MaxFloatingBubbleService
import com.example.max.max.services.MaxForegroundService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class SystemControlPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.max/control")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "controlVolume" -> {
                val direction = call.argument<String>("direction")
                adjustVolume(direction)
                result.success(true)
            }
            "toggleFlashlight" -> {
                val state = call.argument<Boolean>("state") ?: false
                toggleFlashlight(state)
                result.success(true)
            }
            "launchApp" -> {
                val packageName = call.argument<String>("packageName") ?: ""
                val launched = launchApp(packageName)
                result.success(launched)
            }
            "toggleBubble" -> {
                val enable = call.argument<Boolean>("state") ?: false
                toggleBubbleService(enable)
                result.success(true)
            }
            "toggleForegroundService" -> {
                val enable = call.argument<Boolean>("state") ?: false
                toggleForegroundService(enable)
                result.success(true)
            }
            "securityScan" -> {
                // Return Root and Emulator Status
                val isRooted = checkRootMethod()
                val isEmulator = checkEmulatorMethod()
                result.success(mapOf("isRooted" to isRooted, "isEmulator" to isEmulator))
            }
            "openSettingsPanel" -> {
                openSettingsPanel()
                result.success(true)
            }
            "isAccessibilityEnabled" -> {
                val enabled = com.example.max.max.services.MaxAccessibilityService.isServiceRunning()
                result.success(enabled)
            }
            "openAccessibilitySettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ACCESSIBILITY_ERROR", e.message, null)
                }
            }
            "scheduleAutomation" -> {
                val text = call.argument<String>("text") ?: ""
                val scheduled = com.example.max.max.services.MaxAccessibilityService.scheduleMessageSend(text)
                result.success(scheduled)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun adjustVolume(direction: String?) {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val flags = AudioManager.FLAG_SHOW_UI
        if (direction == "up") {
            audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, flags)
        } else if (direction == "down") {
            audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, flags)
        }
    }

    private fun toggleFlashlight(state: Boolean) {
        try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = cameraManager.cameraIdList[0]
            cameraManager.setTorchMode(cameraId, state)
        } catch (e: Exception) {
            Log.e("SystemControlPlugin", "Flashlight error: ${e.message}")
        }
    }

    private fun launchApp(packageName: String): Boolean {
        return try {
            val intent = context.packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                true
            } else {
                // If package not found, launch settings / browser panel as fallback
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun toggleBubbleService(enable: Boolean) {
        val intent = Intent(context, MaxFloatingBubbleService::class.java)
        if (enable) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(context)) {
                context.startService(intent)
            }
        } else {
            context.stopService(intent)
        }
    }

    private fun toggleForegroundService(enable: Boolean) {
        val intent = Intent(context, MaxForegroundService::class.java)
        if (enable) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } else {
            context.stopService(intent)
        }
    }

    private fun openSettingsPanel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Launches modern Android compliant 1-tap settings toggle panel
            val intent = Intent(Settings.Panel.ACTION_WIFI)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } else {
            val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }
    }

    private fun checkRootMethod(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        for (path in paths) {
            if (File(path).exists()) return true
        }
        return false
    }

    private fun checkEmulatorMethod(): Boolean {
        return (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.PRODUCT.indexOf("sdk_google") != -1
    }
}

// Simple Log import helper
object Log {
    fun e(tag: String, msg: String) {
        android.util.Log.e(tag, msg)
    }
}
