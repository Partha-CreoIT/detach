package com.example.detach

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class MyAccessibilityService : AccessibilityService() {

    private val TAG = "MyAccessibilityService"
    private val unblockedApps = mutableMapOf<String, Long>()
    private val cooldownMillis = 5000L // 5 seconds

    private val resetBlockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.detach.RESET_APP_BLOCK") {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    // Add to unblocked apps with current timestamp
                    unblockedApps[packageName] = System.currentTimeMillis()
                    Log.d(TAG, "Reset block for: $packageName and added to unblocked apps")
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        // Register broadcast receiver for reset block
        val filter = IntentFilter("com.example.detach.RESET_APP_BLOCK")
        registerReceiver(resetBlockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(resetBlockReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && event.packageName != null) {
            val packageName = event.packageName.toString()
            val currentTime = System.currentTimeMillis()

            // Check if the app is currently in a cooldown period
            val unblockTime = unblockedApps[packageName]
            if (unblockTime != null) {
                if ((currentTime - unblockTime) < cooldownMillis) {
                    Log.d(TAG, "$packageName is in cooldown period, allowing launch")
                    return
                } else {
                    Log.d(TAG, "$packageName cooldown expired.")
                    unblockedApps.remove(packageName)
                }
            }

            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val blockedApps = prefs.getStringSet("blocked_apps", null)

            if (blockedApps != null && blockedApps.contains(packageName) && packageName != "com.example.detach") {
                Log.d(TAG, "Blocked app opened: $packageName. Launching PauseActivity.")
                
                // Add app to the cooldown list BEFORE launching the activity
                unblockedApps[packageName] = System.currentTimeMillis()
                
                // Try to go back to home screen first to prevent the blocked app from staying in foreground
                try {
                    val homeIntent = Intent(Intent.ACTION_MAIN)
                    homeIntent.addCategory(Intent.CATEGORY_HOME)
                    homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    startActivity(homeIntent)
                    
                    // Small delay to ensure home screen is shown
                    Thread.sleep(100)
                } catch (e: Exception) {
                    Log.e(TAG, "Error going to home screen: ${e.message}")
                }
                
                // Now launch the pause activity
                val intent = Intent(this, PauseActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
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
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or 
                   AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                   AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 50
        }
        serviceInfo = info
    }
}