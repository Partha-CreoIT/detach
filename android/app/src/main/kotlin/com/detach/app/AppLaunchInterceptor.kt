package com.detach.app

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.IBinder
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import android.app.Activity
import com.detach.app.MainActivity

class AppLaunchInterceptor : Service() {
    private val TAG = "AppLaunchInterceptor"
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var handler: Handler
    private var lastEventTime = 0L
    private var serviceStartTime = 0L
    private val startupDelayMillis = 100L // Reduced from 1000ms to 100ms for faster startup
    private val permanentlyBlockedApps = mutableSetOf<String>()
    private var isMonitoringEnabled = true
    private val unblockedApps = mutableMapOf<String, Long>()
    private val cooldownMillis = 2000L // Reduced from 5 seconds to 2 seconds for faster response
    private var lastForegroundApp: String? = null
    private val earlyClosedApps = mutableMapOf<String, Long>()
    private val recentlyBlockedApps = mutableMapOf<String, Long>()
    private val blockCooldownMillis = 1000L // Reduced from 3 seconds to 1 second
    private val pauseLaunchCooldownMillis = 1000L // Reduced from 2 seconds to 1 second
    private val lastPauseLaunchTime = mutableMapOf<String, Long>()
    private val lastBackgroundedTime = mutableMapOf<String, Long>()
    private val backgroundCooldownMillis = 500L // Reduced from 1 second to 500ms

    // Timer management for app sessions
    private val timerRunnables = mutableMapOf<String, Runnable>()

    // Session tracking for timer-based app usage
    private data class AppSession(
        val startTime: Long,
        val durationSeconds: Int,
        val packageName: String
    )

    private val appSessions = mutableMapOf<String, AppSession>()

    companion object {
        var currentlyPausedApp: String? = null
        const val APP_SESSION_PREFIX = "app_session_"
        const val APP_SESSION_DURATION_SUFFIX = "_duration"
    }

    private val resetBlockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.example.detach.RESET_APP_BLOCK" -> {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null) {
                        permanentlyBlockedApps.remove(packageName)
                        unblockedApps[packageName] = System.currentTimeMillis()
                        
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                        blockedApps.remove(packageName)
                        prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                    }
                }
                "com.example.detach.PERMANENTLY_BLOCK_APP" -> {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null) {
                        permanentlyBlockedApps.add(packageName)
                    }
                }
                "com.example.detach.RESET_PAUSE_FLAG" -> {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null && currentlyPausedApp == packageName) {
                        currentlyPausedApp = null
                        android.util.Log.d(TAG, "Reset pause flag for $packageName")
                    }
                }
                "com.example.detach.PAUSE_SCREEN_CLOSED" -> {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null) {
                        currentlyPausedApp = null
                        android.util.Log.d(TAG, "Pause screen closed for $packageName")
                    }
                }
                "com.example.detach.START_APP_SESSION" -> {
                    val packageName = intent.getStringExtra("package_name")
                    val durationSeconds = intent.getIntExtra("duration_seconds", 0)
                    if (packageName != null && durationSeconds > 0) {
                        startAppSession(packageName, durationSeconds)
                    }
                }
                "com.example.detach.APP_BLOCKED" -> {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null) {
                        recentlyBlockedApps[packageName] = System.currentTimeMillis()
                        android.util.Log.d(TAG, "App $packageName was blocked, adding to recently blocked list")
                    }
                }
                "com.example.detach.LAUNCH_APP_WITH_TIMER" -> {
                    val packageName = intent.getStringExtra("package_name")
                    val durationSeconds = intent.getIntExtra("duration_seconds", 0)
                    android.util.Log.d(TAG, "=== Received LAUNCH_APP_WITH_TIMER broadcast ===")
                    android.util.Log.d(TAG, "Package: $packageName, Duration: $durationSeconds")
                    if (packageName != null && durationSeconds > 0) {
                        android.util.Log.d(TAG, "Calling launchAppWithTimer...")
                        launchAppWithTimer(packageName, durationSeconds)
                    } else {
                        android.util.Log.e(TAG, "Invalid parameters: packageName=$packageName, durationSeconds=$durationSeconds")
                    }
                }
                "com.example.detach.TEST_PAUSE_SCREEN" -> {
                    val packageName = intent.getStringExtra("package_name")
                    android.util.Log.d(TAG, "=== Testing pause screen launch for $packageName ===")
                    if (packageName != null) {
                        testPauseScreenLaunch(packageName)
                    }
                }
            }
        }
    }

    private fun launchAppWithTimer(packageName: String, durationSeconds: Int) {
        android.util.Log.d(TAG, "=== launchAppWithTimer called ===")
        android.util.Log.d(TAG, "Package: $packageName, Duration: $durationSeconds seconds")
        
        try {
            // Start the timer first
            android.util.Log.d(TAG, "Starting app session...")
            startAppSession(packageName, durationSeconds)
            
            // Launch the app
            android.util.Log.d(TAG, "Attempting to launch app: $packageName")
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            
            if (launchIntent != null) {
                android.util.Log.d(TAG, "Launch intent created successfully")
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                
                android.util.Log.d(TAG, "Starting activity with intent: $launchIntent")
                startActivity(launchIntent)
                android.util.Log.d(TAG, "Activity startActivity() called successfully")
            } else {
                android.util.Log.e(TAG, "Launch intent is null for package: $packageName")
                // Try alternative method
                try {
                    val intent = Intent(Intent.ACTION_MAIN)
                    intent.addCategory(Intent.CATEGORY_LAUNCHER)
                    intent.setPackage(packageName)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    android.util.Log.d(TAG, "Alternative launch method successful")
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "Alternative launch method also failed: ${e.message}", e)
                }
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error in launchAppWithTimer: ${e.message}", e)
        }
        
        android.util.Log.d(TAG, "=== launchAppWithTimer completed ===")
    }

    private fun startAppSession(packageName: String, durationSeconds: Int) {
        android.util.Log.d(TAG, "=== startAppSession called ===")
        android.util.Log.d(TAG, "Package: $packageName, Duration: $durationSeconds seconds")

        val currentTime = System.currentTimeMillis()
        val session = AppSession(currentTime, durationSeconds, packageName)
        appSessions[packageName] = session

        // Save session data to SharedPreferences for persistence
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"

        prefs.edit()
            .putString(sessionStartKey, currentTime.toString())
            .putInt(sessionDurationKey, durationSeconds)
            .apply()

        android.util.Log.d(TAG, "Session data saved for $packageName")

        // Start the timer
        startTimerForApp(packageName, durationSeconds)
    }

    private fun startTimerForApp(packageName: String, durationSeconds: Int) {
        android.util.Log.d(TAG, "=== startTimerForApp called for $packageName ===")
        
        val timerRunnable = object : Runnable {
            override fun run() {
                val session = appSessions[packageName]
                if (session != null) {
                    val currentTime = System.currentTimeMillis()
                    val elapsedSeconds = (currentTime - session.startTime) / 1000
                    val remainingSeconds = session.durationSeconds - elapsedSeconds

                    android.util.Log.d(TAG, "Timer check for $packageName: elapsed=$elapsedSeconds, remaining=$remainingSeconds, total=$durationSeconds")

                    if (remainingSeconds <= 0) {
                        // Timer expired - handle session end
                        android.util.Log.d(TAG, "Timer expired for $packageName")
                        handleSessionEnd(packageName)
                    } else {
                        // Continue timer - use a more reliable approach
                        handler.postDelayed(this, 1000)
                    }
                } else {
                    android.util.Log.d(TAG, "No active session found for $packageName, stopping timer")
                }
            }
        }

        timerRunnables[packageName] = timerRunnable
        
        // Start the timer immediately
        handler.post(timerRunnable)
        
        android.util.Log.d(TAG, "Timer started for $packageName with duration: $durationSeconds seconds")
    }

    private fun stopTimerForApp(packageName: String) {
        val runnable = timerRunnables[packageName]
        if (runnable != null) {
            handler.removeCallbacks(runnable)
            timerRunnables.remove(packageName)
            android.util.Log.d(TAG, "Timer stopped for $packageName")
        }
    }

    private fun handleSessionEnd(packageName: String) {
        android.util.Log.d(TAG, "=== handleSessionEnd called for $packageName ===")
        
        // Stop the timer
        stopTimerForApp(packageName)
        
        // Add the app back to blocked list
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        
        if (!blockedApps.contains(packageName)) {
            blockedApps.add(packageName)
            prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
            android.util.Log.d(TAG, "Added $packageName back to blocked apps after timer expiration")
        }

        // Clear session data
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"
        prefs.edit()
            .remove(sessionStartKey)
            .remove(sessionDurationKey)
            .apply()
        
        appSessions.remove(packageName)
        android.util.Log.d(TAG, "Session data cleared for $packageName")

        // Force close the target app more aggressively
        try {
            android.util.Log.d(TAG, "Force stopping app: $packageName")
            val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            
            // Method 1: Kill background processes
            am.killBackgroundProcesses(packageName)
            
            // Method 2: Try to force stop using shell command (if available)
            try {
                val process = Runtime.getRuntime().exec(arrayOf("am", "force-stop", packageName))
                process.waitFor()
                android.util.Log.d(TAG, "Force stop command executed for $packageName")
            } catch (e: Exception) {
                android.util.Log.d(TAG, "Could not force stop $packageName using shell command: ${e.message}")
            }
            
            // Method 3: Clear recent tasks to remove the app from recents
            try {
                // Clear recent tasks by restarting the launcher
                val homeIntent = Intent(Intent.ACTION_MAIN)
                homeIntent.addCategory(Intent.CATEGORY_HOME)
                homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(homeIntent)
                android.util.Log.d(TAG, "Recent tasks cleared via home intent")
            } catch (e: Exception) {
                android.util.Log.d(TAG, "Could not clear recent tasks: ${e.message}")
            }
            
            // Longer delay to ensure app is completely closed
            handler.postDelayed({
                // Show pause screen with fresh start flags
                handler.post {
                    try {
                        android.util.Log.d(TAG, "Launching pause screen after timer expiration for $packageName")
                        val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                            // Use flags to ensure fresh start
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                                   Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                                   Intent.FLAG_ACTIVITY_CLEAR_TASK or
                                   Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                            putExtra("blocked_app_package", packageName)
                            putExtra("show_lock", true)
                            putExtra("timer_expired", true)
                            putExtra("timer_state", "expired")
                        }
                        startActivity(pauseIntent)
                        android.util.Log.d(TAG, "Pause screen launched successfully after timer expiration")
                    } catch (e: Exception) {
                        android.util.Log.e(TAG, "Error launching pause screen: ${e.message}", e)
                    }
                }
            }, 2000) // Increased delay to 2 seconds to ensure app is closed
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error handling session end: ${e.message}", e)
        }
    }

    // New method to handle back button press during timer
    private fun handleBackButtonDuringTimer(packageName: String) {
        android.util.Log.d(TAG, "=== handleBackButtonDuringTimer called for $packageName ===")
        
        val session = appSessions[packageName]
        if (session != null) {
            val currentTime = System.currentTimeMillis()
            val elapsedSeconds = (currentTime - session.startTime) / 1000
            val remainingSeconds = session.durationSeconds - elapsedSeconds.toInt()
            
            android.util.Log.d(TAG, "Back button pressed during timer: remaining=$remainingSeconds seconds")
            
            // Show a notification about the active timer
            showTimerNotification(packageName, remainingSeconds)
            
            // Optionally, redirect to Detach app to show timer status
            redirectToDetachApp(packageName, remainingSeconds)
        }
    }

    private fun showTimerNotification(packageName: String, remainingSeconds: Int) {
        try {
            val minutes = remainingSeconds / 60
            val seconds = remainingSeconds % 60
            
            val notification = android.app.Notification.Builder(this, "detach_service_channel")
                .setContentTitle("Timer Active")
                .setContentText("$packageName: ${minutes}m ${seconds}s remaining")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setPriority(android.app.Notification.PRIORITY_HIGH)
                .setAutoCancel(true)
                .build()

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.notify(1002, notification)
            
            android.util.Log.d(TAG, "Timer notification shown for $packageName")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error showing timer notification: ${e.message}", e)
        }
    }

    private fun redirectToDetachApp(packageName: String, remainingSeconds: Int) {
        try {
            val detachIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("show_timer_status", true)
                putExtra("timer_package", packageName)
                putExtra("timer_remaining", remainingSeconds)
            }
            startActivity(detachIntent)
            android.util.Log.d(TAG, "Redirected to Detach app for timer status")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error redirecting to Detach app: ${e.message}", e)
        }
    }

    private fun checkAndHandleEarlyAppClose(packageName: String) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"

        val startTimeStr = prefs.getString(sessionStartKey, null)

        if (startTimeStr != null) {
            val startTime = startTimeStr.toLongOrNull() ?: 0L
            val durationSeconds = prefs.getInt(sessionDurationKey, 0)
            val currentTime = System.currentTimeMillis()
            val elapsedSeconds = (currentTime - startTime) / 1000

            android.util.Log.d(TAG, "Session check: elapsed=$elapsedSeconds, duration=$durationSeconds")

            // Only consider it early close if more than 5 seconds have passed but less than the full duration
            if (elapsedSeconds > 5 && elapsedSeconds < durationSeconds) {
                android.util.Log.d(TAG, "App $packageName closed early - re-blocking")
                
                // Add back to blocked apps
                val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                if (!blockedApps.contains(packageName)) {
                    blockedApps.add(packageName)
                    prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                    android.util.Log.d(TAG, "Added $packageName back to blocked apps")
                }

                // Stop the timer since app was closed
                stopTimerForApp(packageName)
                
                // Clear the session data only for actual early close
                prefs.edit()
                    .remove(sessionStartKey)
                    .remove(sessionDurationKey)
                    .apply()
                appSessions.remove(packageName)
                android.util.Log.d(TAG, "Session data cleared for $packageName (early close)")
                
                // Show early close notification and redirect to Detach app
                showEarlyCloseNotification(packageName, elapsedSeconds.toInt(), durationSeconds)
                redirectToDetachAppAfterEarlyClose(packageName)
                
            } else if (elapsedSeconds >= durationSeconds) {
                android.util.Log.d(TAG, "App $packageName closed after timer finished - normal behavior")
                // Clear session data for normal completion
                prefs.edit()
                    .remove(sessionStartKey)
                    .remove(sessionDurationKey)
                    .apply()
                appSessions.remove(packageName)
                android.util.Log.d(TAG, "Session data cleared for $packageName (normal completion)")
            } else {
                android.util.Log.d(TAG, "App $packageName closed too quickly (${elapsedSeconds}s) - ignoring as false positive, keeping session active")
                // Don't clear session data for false positives - let timer continue
            }
        } else {
            android.util.Log.d(TAG, "No active session found for $packageName")
        }
    }

    private fun showEarlyCloseNotification(packageName: String, elapsedSeconds: Int, totalDuration: Int) {
        try {
            val remainingSeconds = totalDuration - elapsedSeconds
            val minutes = remainingSeconds / 60
            val seconds = remainingSeconds % 60
            
            val notification = android.app.Notification.Builder(this, "detach_service_channel")
                .setContentTitle("Session Ended Early")
                .setContentText("$packageName closed early. ${minutes}m ${seconds}s remaining.")
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setPriority(android.app.Notification.PRIORITY_HIGH)
                .setAutoCancel(true)
                .build()

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.notify(1003, notification)
            
            android.util.Log.d(TAG, "Early close notification shown for $packageName")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error showing early close notification: ${e.message}", e)
        }
    }

    private fun redirectToDetachAppAfterEarlyClose(packageName: String) {
        try {
            val detachIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("show_early_close", true)
                putExtra("early_close_package", packageName)
            }
            startActivity(detachIntent)
            android.util.Log.d(TAG, "Redirected to Detach app after early close")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error redirecting to Detach app after early close: ${e.message}", e)
        }
    }

    // Method to handle user choice after early back
    private fun handleEarlyCloseChoice(packageName: String, choice: String) {
        when (choice) {
            "resume" -> {
                android.util.Log.d(TAG, "User chose to resume timer for $packageName")
                // Re-launch the app with remaining time
                resumeTimerSession(packageName)
            }
            "end" -> {
                android.util.Log.d(TAG, "User chose to end session for $packageName")
                // Session is already ended, just confirm
                confirmSessionEnd(packageName)
            }
            "extend" -> {
                android.util.Log.d(TAG, "User chose to extend timer for $packageName")
                // Extend the timer by 5 minutes
                extendTimerSession(packageName, 300) // 5 minutes = 300 seconds
            }
        }
    }

    private fun resumeTimerSession(packageName: String) {
        try {
            // Get the remaining time from the session
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
            val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"
            
            val startTimeStr = prefs.getString(sessionStartKey, null)
            val durationSeconds = prefs.getInt(sessionDurationKey, 0)
            
            if (startTimeStr != null && durationSeconds > 0) {
                val startTime = startTimeStr.toLongOrNull() ?: 0L
                val currentTime = System.currentTimeMillis()
                val elapsedSeconds = (currentTime - startTime) / 1000
                val remainingSeconds = durationSeconds - elapsedSeconds.toInt()
                
                if (remainingSeconds > 0) {
                    // Remove from blocked apps temporarily
                    val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                    blockedApps.remove(packageName)
                    prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                    
                    // Re-launch the app
                    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(launchIntent)
                        android.util.Log.d(TAG, "Resumed timer session for $packageName")
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error resuming timer session: ${e.message}", e)
        }
    }

    private fun extendTimerSession(packageName: String, additionalSeconds: Int) {
        try {
            val session = appSessions[packageName]
            if (session != null) {
                // Extend the session duration
                val extendedSession = AppSession(session.startTime, session.durationSeconds + additionalSeconds, packageName)
                appSessions[packageName] = extendedSession
                
                // Update SharedPreferences
                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"
                prefs.edit().putInt(sessionDurationKey, session.durationSeconds + additionalSeconds).apply()
                
                android.util.Log.d(TAG, "Extended timer session for $packageName by $additionalSeconds seconds")
                
                // Show notification about extension
                showTimerExtensionNotification(packageName, additionalSeconds)
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error extending timer session: ${e.message}", e)
        }
    }

    private fun showTimerExtensionNotification(packageName: String, additionalSeconds: Int) {
        try {
            val minutes = additionalSeconds / 60
            val seconds = additionalSeconds % 60
            
            val notification = android.app.Notification.Builder(this, "detach_service_channel")
                .setContentTitle("Timer Extended")
                .setContentText("$packageName: +${minutes}m ${seconds}s added")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setPriority(android.app.Notification.PRIORITY_HIGH)
                .setAutoCancel(true)
                .build()

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.notify(1004, notification)
            
            android.util.Log.d(TAG, "Timer extension notification shown for $packageName")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error showing timer extension notification: ${e.message}", e)
        }
    }

    private fun confirmSessionEnd(packageName: String) {
        try {
            val notification = android.app.Notification.Builder(this, "detach_service_channel")
                .setContentTitle("Session Ended")
                .setContentText("$packageName session has been ended")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setPriority(android.app.Notification.PRIORITY_LOW)
                .setAutoCancel(true)
                .build()

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.notify(1005, notification)
            
            android.util.Log.d(TAG, "Session end confirmation shown for $packageName")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error showing session end confirmation: ${e.message}", e)
        }
    }

    private fun testPauseScreenLaunch(packageName: String) {
        android.util.Log.d(TAG, "=== testPauseScreenLaunch called for $packageName ===")
        
        handler.post {
            try {
                val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("blocked_app_package", packageName)
                    putExtra("show_lock", true)
                    putExtra("timer_expired", false)
                    putExtra("timer_state", "test")
                }
                startActivity(pauseIntent)
                android.util.Log.d(TAG, "Test pause screen launched for $packageName")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error launching test pause screen: ${e.message}", e)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()

        serviceStartTime = System.currentTimeMillis()
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        handler = Handler(Looper.getMainLooper())

        android.util.Log.d(TAG, "=== AppLaunchInterceptor.onCreate() called ===")
        android.util.Log.d(TAG, "Service start time: $serviceStartTime")

        // Start as foreground service to prevent freezing
        startForegroundService()

        // Restore active timers from SharedPreferences
        restoreActiveTimers()

        // Register broadcast receiver for all actions
        val filter = IntentFilter().apply {
            addAction("com.example.detach.RESET_APP_BLOCK")
            addAction("com.example.detach.PERMANENTLY_BLOCK_APP")
            addAction("com.example.detach.RESET_PAUSE_FLAG")
            addAction("com.example.detach.PAUSE_SCREEN_CLOSED")
            addAction("com.example.detach.START_APP_SESSION")
            addAction("com.example.detach.APP_BLOCKED")
            addAction("com.example.detach.LAUNCH_APP_WITH_TIMER")
            addAction("com.example.detach.TEST_PAUSE_SCREEN")
        }
        registerReceiver(resetBlockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)

        // Start monitoring immediately
        startMonitoring()
        
        android.util.Log.d(TAG, "Service initialization completed, ready to monitor apps")
    }

    private fun restoreActiveTimers() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val allKeys = prefs.all.keys.filter { it.startsWith(APP_SESSION_PREFIX) && it.endsWith("_start") }
            
            for (startKey in allKeys) {
                val packageName = startKey.removePrefix(APP_SESSION_PREFIX).removeSuffix("_start")
                val durationKey = "${APP_SESSION_PREFIX}${packageName}_duration"
                
                val startTimeStr = prefs.getString(startKey, null)
                val durationSeconds = prefs.getInt(durationKey, 0)
                
                if (startTimeStr != null && durationSeconds > 0) {
                    val startTime = startTimeStr.toLongOrNull() ?: 0L
                    val currentTime = System.currentTimeMillis()
                    val elapsedSeconds = (currentTime - startTime) / 1000
                    val remainingSeconds = durationSeconds - elapsedSeconds
                    
                    if (remainingSeconds > 0) {
                        android.util.Log.d(TAG, "Restoring timer for $packageName: remaining=$remainingSeconds seconds")
                        val session = AppSession(startTime, durationSeconds, packageName)
                        appSessions[packageName] = session
                        startTimerForApp(packageName, durationSeconds)
                    } else {
                        android.util.Log.d(TAG, "Timer for $packageName has expired, cleaning up")
                        // Clean up expired session
                        prefs.edit()
                            .remove(startKey)
                            .remove(durationKey)
                            .apply()
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error restoring active timers: ${e.message}", e)
        }
    }

    private fun startForegroundService() {
        try {
            // Create a simple notification for the foreground service
            val channelId = "detach_service_channel"
            val channelName = "Detach Service"
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channel = android.app.NotificationChannel(
                    channelId,
                    channelName,
                    android.app.NotificationManager.IMPORTANCE_LOW
                )
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                notificationManager.createNotificationChannel(channel)
            }

            val notification = android.app.Notification.Builder(this, channelId)
                .setContentTitle("Detach")
                .setContentText("Monitoring app usage")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setPriority(android.app.Notification.PRIORITY_LOW)
                .setOngoing(true)
                .build()

            startForeground(1001, notification)
            android.util.Log.d(TAG, "Service started as foreground service")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error starting foreground service: ${e.message}", e)
        }
    }

    private fun startMonitoring() {
        Executors.newSingleThreadScheduledExecutor().scheduleAtFixedRate({
            try {
                monitorAppUsage()
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error in monitoring: ${e.message}", e)
            }
        }, 0, 100, TimeUnit.MILLISECONDS) // Increased from 10ms to 100ms to reduce frequency
    }

    private fun monitorAppUsage() {
        val currentTime = System.currentTimeMillis()
        val events = usageStatsManager.queryEvents(lastEventTime, currentTime)
        val event = UsageEvents.Event()
        var eventProcessed = false
        
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            eventProcessed = true

            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                val packageName = event.packageName
                android.util.Log.d(TAG, "=== App moved to foreground: $packageName ===")
                android.util.Log.d(TAG, "Last foreground app: $lastForegroundApp")
                android.util.Log.d(TAG, "Service start time: $serviceStartTime")
                android.util.Log.d(TAG, "Current time: $currentTime")
                android.util.Log.d(TAG, "Startup delay: $startupDelayMillis")
                
                if (packageName != null) {
                    if (packageName == "com.detach.app") {
                        lastForegroundApp = packageName
                        android.util.Log.d(TAG, "Detach app launched, setting as last foreground app")
                    } else {
                        // Always handle app launch for non-Detach apps
                        android.util.Log.d(TAG, "Handling app launch for: $packageName")
                        handleAppLaunch(packageName)
                        lastForegroundApp = packageName
                    }
                }
            }
            if (event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND) {
                val packageName = event.packageName
                if (packageName != null && packageName != "com.detach.app") {
                    handleAppBackgrounded(packageName)
                }
            }
        }
        
        // Only update lastEventTime if we actually processed events
        if (eventProcessed) {
            lastEventTime = currentTime
        }
    }

    private fun handleAppLaunch(packageName: String) {
        // Don't handle Detach app itself
        if (packageName == "com.detach.app") {
            android.util.Log.d(TAG, "Detach app launched, ignoring")
            return
        }
        
        android.util.Log.d(TAG, "=== handleAppLaunch called for $packageName ===")
        
        // Check if service just started - but allow immediate detection for blocked apps
        val currentTime = System.currentTimeMillis()
        val serviceAge = currentTime - serviceStartTime
        android.util.Log.d(TAG, "Service age: ${serviceAge}ms, Startup delay: ${startupDelayMillis}ms")
        
        // Only skip if service is very new (less than 500ms) to allow immediate detection
        if (serviceAge < 500) {
            android.util.Log.d(TAG, "Service very new (${serviceAge}ms), but will still check for blocked apps")
        }
        
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)

        // Check if app has an active session - if so, don't show pause screen
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionStartStr = prefs.getString(sessionStartKey, null)
        if (sessionStartStr != null) {
            android.util.Log.d(TAG, "App $packageName has active session, not showing pause screen")
            return
        }

        // Check if app is blocked
        val blockedApps = prefs.getStringSet("blocked_apps", null)
        android.util.Log.d(TAG, "Checking if $packageName is blocked. Blocked apps: $blockedApps")

        if (blockedApps != null && blockedApps.contains(packageName)) {
            android.util.Log.d(TAG, "App $packageName is blocked, showing pause screen")

            // Check cooldown to prevent rapid launches (but make it shorter)
            val lastLaunchTime = lastPauseLaunchTime[packageName] ?: 0L
            if ((currentTime - lastLaunchTime) < 500) { // Reduced to 500ms
                android.util.Log.d(TAG, "Pause screen cooldown active for $packageName, skipping")
                return
            }

            handler.post {
                try {
                    android.util.Log.d(TAG, "Launching pause screen for $packageName...")
                    val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra("blocked_app_package", packageName)
                        putExtra("show_lock", true)
                        putExtra("timer_expired", false)
                        putExtra("timer_state", "normal")
                    }
                    startActivity(pauseIntent)
                    lastPauseLaunchTime[packageName] = currentTime
                    android.util.Log.d(TAG, "Pause screen launched successfully for $packageName")
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "Error launching pause screen: ${e.message}", e)
                }
            }
        } else {
            android.util.Log.d(TAG, "App $packageName is NOT blocked or blockedApps is null")
        }
    }

    private fun handleAppBackgrounded(packageName: String) {
        // Don't handle Detach app itself
        if (packageName == "com.detach.app") {
            return
        }

        // Check if this app has an active session
        val session = appSessions[packageName]
        if (session != null) {
            android.util.Log.d(TAG, "App $packageName backgrounded with active session - continuing timer")
            // Don't stop the timer, let it continue running
            return
        }

        // Check cooldown to prevent rapid processing
        val lastBackgroundTime = lastBackgroundedTime[packageName] ?: 0L
        val currentTime = System.currentTimeMillis()
        if ((currentTime - lastBackgroundTime) < backgroundCooldownMillis) {
            android.util.Log.d(TAG, "Background cooldown active for $packageName, skipping")
            return
        }
        lastBackgroundedTime[packageName] = currentTime

        // Check if this app was recently blocked
        val recentlyBlockedTime = recentlyBlockedApps[packageName] ?: 0L
        if ((currentTime - recentlyBlockedTime) < blockCooldownMillis) {
            android.util.Log.d(TAG, "App $packageName recently blocked, skipping background check")
            return
        }

        // Check for early app close
        checkAndHandleEarlyAppClose(packageName)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d(TAG, "=== onStartCommand called ===")
        android.util.Log.d(TAG, "Intent: $intent")
        android.util.Log.d(TAG, "Action: ${intent?.action}")
        
        if (intent != null) {
            val action = intent.action
            when (action) {
                "com.example.detach.START_APP_SESSION" -> {
                    val packageName = intent.getStringExtra("package_name")
                    val durationSeconds = intent.getIntExtra("duration_seconds", 0)
                    android.util.Log.d(TAG, "Handling START_APP_SESSION: package=$packageName, duration=$durationSeconds")
                    if (packageName != null && durationSeconds > 0) {
                        startAppSession(packageName, durationSeconds)
                    }
                }
                "com.example.detach.LAUNCH_APP_WITH_TIMER" -> {
                    val packageName = intent.getStringExtra("package_name")
                    val durationSeconds = intent.getIntExtra("duration_seconds", 0)
                    android.util.Log.d(TAG, "Handling LAUNCH_APP_WITH_TIMER: package=$packageName, duration=$durationSeconds")
                    if (packageName != null && durationSeconds > 0) {
                        launchAppWithTimer(packageName, durationSeconds)
                    }
                }
                else -> {
                    android.util.Log.d(TAG, "Unknown action: $action")
                }
            }
        } else {
            android.util.Log.d(TAG, "Intent is null")
        }
        
        android.util.Log.d(TAG, "=== onStartCommand completed ===")
        return START_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        
        // Stop all active timers
        timerRunnables.keys.forEach { packageName ->
            stopTimerForApp(packageName)
        }

        try {
            unregisterReceiver(resetBlockReceiver)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error unregistering receiver: ${e.message}", e)
        }
        currentlyPausedApp = null
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
}