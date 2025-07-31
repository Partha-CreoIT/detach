package com.detach.app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.os.Handler
import android.os.Looper

class AppLaunchAccessibilityService : AccessibilityService() {
    private val TAG = "AppLaunchAccessibility"
    private var lastDetectedPackage: String? = null
    private var lastDetectionTime: Long = 0
    private val handler = Handler(Looper.getMainLooper())
    
    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        
        // Skip our own app and system UI
        if (packageName == "com.detach.app" || 
            packageName == "com.android.systemui" ||
            packageName.startsWith("com.android.")) {
            return
        }
        
        // Process all event types for better detection
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_FOCUSED,
            AccessibilityEvent.TYPE_VIEW_CLICKED,
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> {
                // Prevent duplicate processing within 500ms
                val currentTime = System.currentTimeMillis()
                if (packageName == lastDetectedPackage && 
                    currentTime - lastDetectionTime < 500) {
                    return
                }
                
                // Check if this is a blocked app
                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                val blockedAppsString = prefs.getString("flutter.blocked_apps", "[]")
                val blockedApps = try {
                    // Parse the Flutter list format ["app1", "app2", ...]
                    blockedAppsString?.removeSurrounding("[", "]")
                        ?.split(", ")
                        ?.map { it.trim().removeSurrounding("\"") }
                        ?.toSet() ?: emptySet()
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "Error parsing blocked apps: ${e.message}")
                    emptySet<String>()
                }
                
                if (blockedApps.contains(packageName)) {
                    android.util.Log.d(TAG, "BLOCKED APP DETECTED: $packageName, Event: ${event.eventType}")
                    lastDetectedPackage = packageName
                    lastDetectionTime = currentTime
                    
                    // Special handling for Facebook - hold its process instead of killing
                    if (packageName == "com.facebook.katana") {
                        android.util.Log.d(TAG, "Facebook detected - holding its process")
                        
                        // Immediately send it to background using back gesture
                        performGlobalAction(GLOBAL_ACTION_BACK)
                        
                        // Also try to send HOME to ensure it goes to background
                        handler.postDelayed({
                            performGlobalAction(GLOBAL_ACTION_HOME)
                        }, 100)
                    }
                    
                    // Immediately intercept and show pause screen
                    interceptBlockedApp(packageName)
                }
            }
        }
    }
    
    private fun interceptBlockedApp(packageName: String) {
        android.util.Log.d(TAG, "INTERCEPTING BLOCKED APP: $packageName")
        
        // Save the blocked app info
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        prefs.edit().putString("flutter.last_foreground_app", packageName).apply()
        
        // Launch pause screen with highest priority
        handler.post {
            try {
                val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                           Intent.FLAG_ACTIVITY_CLEAR_TASK or 
                           Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                           Intent.FLAG_ACTIVITY_NO_ANIMATION
                    putExtra("blocked_app_package", packageName)
                    putExtra("show_lock", true)
                    putExtra("timer_expired", false)
                    putExtra("timer_state", "normal")
                    putExtra("immediate_block", true)
                    putExtra("overlay_mode", true)
                    addCategory(Intent.CATEGORY_HOME)
                }
                startActivity(pauseIntent)
                
                // Also try to bring our app to front using recents
                val am = getSystemService(android.content.Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                am.moveTaskToFront(pauseIntent.component?.className?.hashCode() ?: 0, 0)
                
                // Try to perform back gesture to close the blocked app
                performGlobalAction(GLOBAL_ACTION_BACK)
                
                android.util.Log.d(TAG, "Pause screen launched for $packageName")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error launching pause screen: ${e.message}", e)
            }
        }
    }
    
    override fun onInterrupt() {
        android.util.Log.d(TAG, "Accessibility service interrupted")
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        android.util.Log.d(TAG, "Accessibility service connected")
    }
} 