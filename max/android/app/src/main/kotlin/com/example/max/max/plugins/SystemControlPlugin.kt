package com.example.max.max.plugins

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.accessibilityservice.AccessibilityService
import android.app.Activity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import com.example.max.max.services.MaxFloatingBubbleService
import com.example.max.max.services.MaxForegroundService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import com.google.firebase.firestore.FirebaseFirestore

class SystemControlPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private lateinit var firestore: FirebaseFirestore
    private lateinit var sharedPrefs: SharedPreferences

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.max/control")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        firestore = FirebaseFirestore.getInstance()
        sharedPrefs = context.getSharedPreferences("user_prefs", Context.MODE_PRIVATE)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
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
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                    activity?.let {
                        ActivityCompat.requestPermissions(
                            it,
                            arrayOf(Manifest.permission.CAMERA),
                            1001
                        )
                    }
                    result.error("PERMISSION_DENIED", "Camera permission not granted", null)
                } else {
                    toggleFlashlight(state)
                    result.success(true)
                }
            }
            "launchApp" -> {
                val packageName = call.argument<String>("packageName") ?: ""
                val launched = launchApp(packageName)
                result.success(launched)
            }
            "toggleBubble" -> {
                val enable = call.argument<Boolean>("state") ?: false
                if (!Settings.canDrawOverlays(context)) {
                    // Request overlay permission
                    activity?.let {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:" + context.packageName)
                        )
                        it.startActivity(intent)
                    }
                    result.error("OVERLAY_DENIED", "Overlay permission not granted", null)
                } else {
                    toggleBubbleService(enable)
                    result.success(true)
                }
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
                val enabled = isAccessibilityServiceEnabled(context, com.example.max.max.services.MaxAccessibilityService::class.java)
                result.success(enabled)
            }
            "openAccessibilitySettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    val launchContext = activity ?: context
                    if (launchContext == context) {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    launchContext.startActivity(intent)
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
            "callPhone" -> {
                val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                val called = callPhone(phoneNumber)
                val reply = if (called) "hey Max, I called $phoneNumber" else "hey Max, could not call $phoneNumber"
                result.success(reply)
            }
            "lockPhone" -> {
                val locked = com.example.max.max.services.MaxAccessibilityService.lockScreen()
                if (locked) {
                    result.success("Phone locked")
                } else {
                    result.error("LOCK_ERROR", "Accessibility service not active. Please enable it in Settings.", null)
                }
            }
            "setBorderMode" -> {
                val mode = call.argument<String>("mode") ?: "idle"
                if (!Settings.canDrawOverlays(context)) {
                    result.error("OVERLAY_DENIED", "Overlay permission not granted", null)
                } else {
                    val intent = Intent(context, com.example.max.max.services.MaxBorderAnimService::class.java).apply {
                        action = com.example.max.max.services.MaxBorderAnimService.ACTION_START
                        putExtra(com.example.max.max.services.MaxBorderAnimService.EXTRA_MODE, mode)
                    }
                    if (mode == "idle") {
                        // Stop border service when idle
                        context.stopService(Intent(context, com.example.max.max.services.MaxBorderAnimService::class.java))
                    } else {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(intent)
                        } else {
                            context.startService(intent)
                        }
                    }
                    result.success(true)
                }
            }
            
                        "saveData" -> {
                val collection = call.argument<String>("collection") ?: ""
                val data = call.argument<Map<String, Any>>("data") ?: emptyMap()
                val docId = call.argument<String>("docId")
                if (collection.isEmpty()) {
                    result.error("FIRESTORE_ERROR", "Collection name required", null)
                } else {
                    val collRef = firestore.collection(collection)
                    if (!docId.isNullOrEmpty()) {
                        collRef.document(docId).set(data)
                            .addOnSuccessListener { result.success(true) }
                            .addOnFailureListener { e -> result.error("FIRESTORE_ERROR", e.message, null) }
                    } else {
                        collRef.add(data)
                            .addOnSuccessListener { result.success(true) }
                            .addOnFailureListener { e -> result.error("FIRESTORE_ERROR", e.message, null) }
                    }
                }
            }
            "setUserName" -> {
                val name = call.argument<String>("name") ?: ""
                setUserName(name)
                result.success(true)
            }
            "getUserName" -> {
                val stored = getUserName()
                result.success(stored)
            }
            "setSirName" -> {
                val sir = call.argument<String>("sir") ?: ""
                setSirName(sir)
                result.success(true)
            }
            "getSirName" -> {
                val stored = getSirName()
                result.success(stored)
            }
            "getFullName" -> {
                result.success(getFullName())
            }
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

    private fun callPhone(phoneNumber: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:$phoneNumber")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            try {
                val intent = Intent(Intent.ACTION_DIAL).apply {
                    data = Uri.parse("tel:$phoneNumber")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                true
            } catch (ex: Exception) {
                false
            }
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context, service: Class<out AccessibilityService>): Boolean {
        val expectedComponentName = ComponentName(context, service)
        val enabledServicesSetting = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = android.text.TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledService = ComponentName.unflattenFromString(componentNameString)
            if (enabledService != null && enabledService == expectedComponentName) {
                return true
            }
        }
        return false
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

    // Resolve common app names to package identifiers
    private fun resolvePackageName(name: String): String? {
        val lower = name.lowercase()
        val map = mapOf(
            "youtube" to "com.google.android.youtube",
            "instagram" to "com.instagram.android",
            "whatsapp" to "com.whatsapp",
            "facebook" to "com.facebook.katana",
            "twitter" to "com.twitter.android",
            "maps" to "com.google.android.apps.maps"
        )
        // Return mapped package name or assume the provided string is already a package name
        return map[lower] ?: name
    }

    private fun launchApp(appIdentifier: String): Boolean {
        // Resolve possible friendly name to a package name
        val packageName = resolvePackageName(appIdentifier) ?: return false
        return try {
            val intent = context.packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                true
            } else {
                // Package not found
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun toggleBubbleService(enable: Boolean) {
        val intent = Intent(context, MaxFloatingBubbleService::class.java)
        if (enable) {
            if (Settings.canDrawOverlays(context)) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } else {
                // Request overlay permission
                activity?.let {
                    val permissionIntent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:" + context.packageName)
                    )
                    it.startActivity(permissionIntent)
                }
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
    // sharedPrefs initialized in onAttachedToEngine

    private fun setUserName(name: String) {
        sharedPrefs.edit().putString("user_name", name).apply()
    }

    private fun getUserName(): String {
        return sharedPrefs.getString("user_name", "") ?: ""
    }

    private fun setSirName(sir: String) {
        sharedPrefs.edit().putString("sir_name", sir).apply()
    }

    private fun getSirName(): String {
        return sharedPrefs.getString("sir_name", "") ?: ""
    }

    private fun getFullName(): String {
        val first = getUserName()
        val sir = getSirName()
        return if (first.isNotBlank() && sir.isNotBlank()) "$first $sir" else first + sir
    }

}

// Simple Log import helper
object Log {
    fun e(tag: String, msg: String) {
        android.util.Log.e(tag, msg)
    }
}
