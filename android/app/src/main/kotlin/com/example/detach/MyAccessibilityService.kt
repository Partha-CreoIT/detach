package com.example.detach

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class MyAccessibilityService : AccessibilityService() {

    private val TAG = "MyAccessibilityService"
    // Cooldown mechanism to prevent re-blocking the same app immediately.
    private val unblockedApps = mutableMapOf<String, Long>()
    private val cooldownMillis = 5000L // 5 seconds

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && event.packageName != null) {
            val packageName = event.packageName.toString()
            val currentTime = System.currentTimeMillis()

            // Check if the app is currently in a cooldown period.
            val unblockTime = unblockedApps[packageName]
            if (unblockTime != null) {
                if ((currentTime - unblockTime) < cooldownMillis) {
                    Log.d(TAG, "$packageName is in cooldown. Ignoring.")
                    return // Still in cooldown, so we do nothing.
                } else {
                    // Cooldown has expired, remove it so the app can be blocked again in the future.
                    Log.d(TAG, "$packageName cooldown expired.")
                    unblockedApps.remove(packageName)
                }
            }

            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val blockedApps = prefs.getStringSet("blocked_apps", null)

            if (blockedApps != null && blockedApps.contains(packageName) && packageName != "com.example.detach") {
                Log.d(TAG, "Blocked app opened: $packageName. Launching PauseActivity.")
                // Add app to the cooldown list BEFORE launching the activity.
                unblockedApps[packageName] = System.currentTimeMillis()
                val intent = Intent(this, PauseActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    putExtra("blocked_app_package", packageName)
                }
                startActivity(intent)
            }
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility Service interrupted.")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility Service connected.")
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        }
        serviceInfo = info
    }
}