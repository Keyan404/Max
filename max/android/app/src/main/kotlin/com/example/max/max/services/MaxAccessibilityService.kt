package com.example.max.max.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

class MaxAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "MaxAccessibility"
        private var instance: MaxAccessibilityService? = null
        
        // Automated typing state
        private var pendingTextToType: String? = null
        private var automationActive = false

        /**
         * Static helper to schedule automation.
         */
        fun scheduleMessageSend(text: String): Boolean {
            val service = instance
            if (service == null) {
                Log.e(TAG, "Cannot schedule: Accessibility Service is not running/connected.")
                return false
            }
            pendingTextToType = text
            automationActive = true
            Log.d(TAG, "Scheduled automation task: '$text'")
            return true
        }
        
        /**
         * Checks if the service instance is active.
         */
        fun isServiceRunning(): Boolean {
            return instance != null
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Accessibility Service Connected")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "Accessibility Service Destroyed")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (!automationActive || pendingTextToType == null) return

        val rootNode = rootInActiveWindow ?: return
        val packageName = event.packageName?.toString() ?: ""

        Log.d(TAG, "Event in package: $packageName")
        
        // Run automation based on current package
        when {
            packageName.contains("whatsapp") -> {
                automateMessaging(rootNode, "com.whatsapp:id/entry", "com.whatsapp:id/send")
            }
            packageName.contains("telegram") -> {
                // Telegram doesn't expose ID easily, use ClassName and ContentDescription matches
                automateMessaging(rootNode, null, null, "Message", "Send")
            }
            packageName.contains("messaging") || packageName.contains("mms") -> {
                // Standard Android SMS
                automateMessaging(rootNode, "com.google.android.apps.messaging:id/compose_message_text", "com.google.android.apps.messaging:id/send_message_button")
            }
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility Service Interrupted")
    }

    private fun automateMessaging(
        rootNode: AccessibilityNodeInfo,
        inputFieldId: String?,
        sendButtonId: String?,
        inputDescFallback: String = "",
        sendDescFallback: String = ""
    ) {
        var inputNode: AccessibilityNodeInfo? = null
        var sendNode: AccessibilityNodeInfo? = null

        // 1. Find the Input Node
        if (inputFieldId != null) {
            val list = rootNode.findAccessibilityNodeInfosByViewId(inputFieldId)
            if (list.isNotEmpty()) inputNode = list[0]
        }
        
        if (inputNode == null) {
            inputNode = findNodeByMatch(rootNode) { node ->
                node.className?.contains("EditText") == true ||
                node.contentDescription?.toString()?.contains(inputDescFallback, ignoreCase = true) == true
            }
        }

        // 2. Find the Send Node
        if (sendButtonId != null) {
            val list = rootNode.findAccessibilityNodeInfosByViewId(sendButtonId)
            if (list.isNotEmpty()) sendNode = list[0]
        }
        
        if (sendNode == null) {
            sendNode = findNodeByMatch(rootNode) { node ->
                node.className?.contains("Button") == true ||
                node.contentDescription?.toString()?.contains(sendDescFallback, ignoreCase = true) == true ||
                node.text?.toString()?.contains(sendDescFallback, ignoreCase = true) == true
            }
        }

        // 3. Execute Automation Actions
        if (inputNode != null && sendNode != null && pendingTextToType != null) {
            Log.d(TAG, "Found input and send node. Auto-typing...")
            
            // Set text action
            val arguments = Bundle().apply {
                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, pendingTextToType)
            }
            inputNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)

            // Click action
            sendNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)

            // Reset state
            pendingTextToType = null
            automationActive = false
            Log.d(TAG, "Automation typing completed.")
        }
    }

    private fun findNodeByMatch(
        node: AccessibilityNodeInfo,
        matcher: (AccessibilityNodeInfo) -> Boolean
    ): AccessibilityNodeInfo? {
        if (matcher(node)) return node
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findNodeByMatch(child, matcher)
            if (result != null) return result
        }
        return null
    }
}
