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
import android.app.AlarmManager
import android.app.PendingIntent
import android.os.Build
import android.os.PowerManager
import com.detach.app.MainActivity

class AppLaunchInterceptor : Service() {
    private val TAG = "AppLaunchInterceptor"
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var handler: Handler
    private var lastEventTime = 0L
    private var serviceStartTime = 0L
    private val startupDelayMillis = 3000L // Reduced for faster interception
    private var isServiceFullyInitialized = false
    
    // Service restart management
    private lateinit var serviceRestartManager: ServiceRestartManager
    private var wakeLock: PowerManager.WakeLock? = null
    private lateinit var alarmManager: AlarmManager
    private var restartPendingIntent: PendingIntent? = null
    
    // Enhanced startup app tracking
    private val startupRunningApps = mutableSetOf<String>()
    private var startupAppsDetected = false
    
    private val permanentlyBlockedApps = mutableSetOf<String>()
    private var isMonitoringEnabled = true
    private val unblockedApps = mutableMapOf<String, Long>()
    private val cooldownMillis = 3000L
    private var lastForegroundApp: String? = null
    private val earlyClosedApps = mutableMapOf<String, Long>()
    private val recentlyBlockedApps = mutableMapOf<String, Long>()
    private val blockCooldownMillis = 2000L
    private val pauseLaunchCooldownMillis = 2000L // Reduced cooldown
    private val lastPauseLaunchTime = mutableMapOf<String, Long>()
    private val lastBackgroundedTime = mutableMapOf<String, Long>()
    private val heldApps = mutableMapOf<String, Long>() // Track apps being held instead of killed
    private val backgroundCooldownMillis = 1000L

    // Timer management for app sessions
    private val timerRunnables = mutableMapOf<String, Runnable>()

    // Session tracking for timer-based app usage with persistent storage
    private val appSessions = mutableMapOf<String, AppSession>()
    private val APP_SESSION_PREFIX = "app_session_"
    private val REMAINING_TIME_PREFIX = "remaining_time_"
    private val SESSION_START_PREFIX = "session_start_"
    
    // Enhanced foreground management
    private var isDetachInForeground = false
    private var currentlyPausedApp: String? = null
    private val pendingAppLaunches = mutableMapOf<String, Long>()
    private val launchCooldownMillis = 1500L

    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "detach_service_channel"
        private const val FOREGROUND_SERVICE_ID = 1001
        private const val RESTART_ACTION = "com.detach.app.RESTART_SERVICE"
        private const val SERVICE_RESTART_INTERVAL = 5 * 60 * 1000L // 5 minutes
    }

    data class AppSession(
        val packageName: String,
        val startTime: Long,
        val duration: Long,
        val isActive: Boolean = true,
        val originalDuration: Long = duration // Track original duration for accurate remaining time
    )

    // Service restart receiver
    private val serviceRestartReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == RESTART_ACTION) {
                android.util.Log.d(TAG, "Service restart triggered")
                startService(Intent(context, AppLaunchInterceptor::class.java))
            }
        }
    }

    // Enhanced remaining time calculation with persistent storage
    private fun saveRemainingTime(packageName: String, remainingSeconds: Int) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val currentTime = System.currentTimeMillis()
        
        prefs.edit()
            .putInt("${REMAINING_TIME_PREFIX}${packageName}", remainingSeconds)
            .putLong("${SESSION_START_PREFIX}${packageName}", currentTime)
            .putLong("session_pause_${packageName}", currentTime)
            .apply()
        
        android.util.Log.d(TAG, "Saved remaining time for $packageName: ${remainingSeconds}s at ${currentTime}")
    }

    private fun getRemainingTime(packageName: String): Int {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val remainingSeconds = prefs.getInt("${REMAINING_TIME_PREFIX}${packageName}", 0)
        val pauseTime = prefs.getLong("session_pause_${packageName}", 0L)
        val currentTime = System.currentTimeMillis()
        
        // If pause time is too old (more than 24 hours), clear the data
        if (pauseTime > 0 && (currentTime - pauseTime) > 24 * 60 * 60 * 1000) {
            clearRemainingTime(packageName)
            return 0
        }
        
        return remainingSeconds
    }

    private fun clearRemainingTime(packageName: String) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        prefs.edit()
            .remove("${REMAINING_TIME_PREFIX}${packageName}")
            .remove("${SESSION_START_PREFIX}${packageName}")
            .remove("session_pause_${packageName}")
            .apply()
        
        android.util.Log.d(TAG, "Cleared remaining time for $packageName")
    }

    // Enhanced service persistence
    private fun setupServiceRestart() {
        alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val restartIntent = Intent(this, AppLaunchInterceptor::class.java).apply {
            action = RESTART_ACTION
        }
        
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        restartPendingIntent = PendingIntent.getService(this, 0, restartIntent, flags)
        
        // Set up periodic restart alarm
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + SERVICE_RESTART_INTERVAL,
                restartPendingIntent!!
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + SERVICE_RESTART_INTERVAL,
                restartPendingIntent!!
            )
        }
        
        android.util.Log.d(TAG, "Service restart alarm set for ${SERVICE_RESTART_INTERVAL}ms")
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
                        
                        // Clear any pending launches for this app
                        pendingAppLaunches.remove(packageName)
                        
                        // Release held app if it's Facebook
                        if (packageName == "com.facebook.katana" && heldApps.containsKey(packageName)) {
                            releaseHeldApp(packageName)
                        }
                    }
                }
                "com.example.detach.FLUTTER_APP_KILLED" -> {
                    android.util.Log.d(TAG, "Flutter app killed, stopping all active timers")
                    // Stop all active timers and re-block apps
                    val activeApps = appSessions.keys.toList()
                    activeApps.forEach { packageName ->
                        stopTimerForApp(packageName)
                        
                        // Re-block the app
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                        if (!blockedApps.contains(packageName)) {
                            blockedApps.add(packageName)
                            prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                            android.util.Log.d(TAG, "TIMER OFF: $packageName (Flutter app killed)")
                        }
                    }
                }
                "com.example.detach.PERMANENTLY_BLOCK_APP" -> {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null) {
                        android.util.Log.d(TAG, "BROADCAST: Received PERMANENTLY_BLOCK_APP for $packageName")
                        permanentlyBlockedApps.add(packageName)
                        // Clear any pending launches for this app
                        pendingAppLaunches.remove(packageName)
                        
                        // Ensure app is in blocked list in SharedPreferences
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                        if (!blockedApps.contains(packageName)) {
                            blockedApps.add(packageName)
                            prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                            android.util.Log.d(TAG, "BROADCAST: Added $packageName to blocked list")
                        } else {
                            android.util.Log.d(TAG, "BROADCAST: $packageName already in blocked list")
                        }
                        android.util.Log.d(TAG, "BROADCAST: Current blocked apps: $blockedApps")
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
                    val durationSeconds = intent.getLongExtra("duration_seconds", 0)
                    if (packageName != null && durationSeconds > 0) {
                        startAppSession(packageName, durationSeconds)
                    }
                }
                "com.example.detach.APP_BLOCKED" -> {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null) {
                        android.util.Log.d(TAG, "App blocked notification received for $packageName")
                        // Mark as recently blocked to prevent immediate re-blocking
                        recentlyBlockedApps[packageName] = System.currentTimeMillis()
                    }
                }
                "com.example.detach.LAUNCH_APP_WITH_TIMER" -> {
                    val packageName = intent.getStringExtra("package_name")
                    val durationSeconds = intent.getIntExtra("duration_seconds", 0)
                    if (packageName != null && durationSeconds > 0) {
                        handleLaunchAppWithTimer(packageName, durationSeconds)
                    }
                }
                "com.example.detach.TEST_PAUSE_SCREEN" -> {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null) {
                        android.util.Log.d(TAG, "Testing pause screen for $packageName")
                        showPauseScreen(packageName)
                    }
                }
                "com.example.detach.CLEAR_PAUSE_FLAG" -> {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null) {
                        currentlyPausedApp = null
                        android.util.Log.d(TAG, "Manually cleared currentlyPausedApp for $packageName")
                    } else {
                        // Clear all pause flags
                        currentlyPausedApp = null
                        android.util.Log.d(TAG, "Manually cleared all currentlyPausedApp flags")
                    }
                }
            }
        }
    }

    private fun handleLaunchAppWithTimer(packageName: String, durationSeconds: Int) {
        // Remove app from blocked list temporarily for the timer session
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        if (blockedApps.contains(packageName)) {
            blockedApps.remove(packageName)
            prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
        }
        
        // Clear the currently paused app flag
        if (currentlyPausedApp == packageName) {
            currentlyPausedApp = null
        }
        
        // Start the app session
        startAppSession(packageName, durationSeconds.toLong())
        
        // Launch the app after a short delay to ensure session is set up
        handler.postDelayed({
            try {
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(launchIntent)
                    android.util.Log.d(TAG, "TIMER ON: $packageName for ${durationSeconds}s")
                } else {
                    android.util.Log.e(TAG, "Could not get launch intent for $packageName")
                }
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error launching $packageName: ${e.message}", e)
            }
        }, 500)
    }

    private fun startAppSession(packageName: String, durationSeconds: Long) {
        val startTime = System.currentTimeMillis()
        val session = AppSession(packageName, startTime, durationSeconds * 1000)
        appSessions[packageName] = session
        
        // Save session data to SharedPreferences
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"
        
        prefs.edit()
            .putString(sessionStartKey, startTime.toString())
            .putLong(sessionDurationKey, durationSeconds)
            .apply()
        
        android.util.Log.d(TAG, "Started app session for $packageName: ${durationSeconds}s")
        
        // Save timer start info to SharedPreferences for Flutter to read
        prefs.edit()
            .putString("timer_started_${packageName}", "true")
            .putInt("timer_duration_${packageName}", durationSeconds.toInt())
            .apply()
        
        android.util.Log.d(TAG, "Saved timer start info for $packageName: ${durationSeconds}s")
        
        // Start timer to end session
        val timerRunnable = Runnable {
            endAppSession(packageName)
        }
        timerRunnables[packageName] = timerRunnable
        handler.postDelayed(timerRunnable, durationSeconds * 1000)
        
        android.util.Log.d(TAG, "Timer set for $packageName: ${durationSeconds}s")
    }

    private fun startTimerForApp(packageName: String, durationSeconds: Int) {
        android.util.Log.d(TAG, "Starting timer for $packageName with ${durationSeconds}s remaining")
        startAppSession(packageName, durationSeconds.toLong())
    }

    private fun endAppSession(packageName: String) {
        // Remove from active sessions
        appSessions.remove(packageName)
        timerRunnables.remove(packageName)
        
        // Clear session data
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"
        
        prefs.edit()
            .remove(sessionStartKey)
            .remove(sessionDurationKey)
            .apply()
        
        // Add app back to blocked list
        val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        if (!blockedApps.contains(packageName)) {
            blockedApps.add(packageName)
            prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
            android.util.Log.d(TAG, "TIMER EXPIRED: Added $packageName back to blocked list")
        } else {
            android.util.Log.d(TAG, "TIMER EXPIRED: $packageName already in blocked list")
        }

        // Force stop the app to ensure it's closed
        forceStopApp(packageName)
        
        // Show notification about timer completion
        showTimerCompletedNotification(packageName)
        
        // Clear the currently paused app flag so pause screen can show again
        if (currentlyPausedApp == packageName) {
            currentlyPausedApp = null
        }
        
        // Calculate elapsed time for timer expiration
        val session = appSessions[packageName]
        val elapsedTime = if (session != null) {
            val currentTime = System.currentTimeMillis()
            ((currentTime - session.startTime) / 1000).toInt()
        } else {
            0
        }
        
        // Save timer expiration info to SharedPreferences for Flutter to read
        prefs.edit()
            .putString("timer_expired_${packageName}", "true")
            .putInt("timer_elapsed_${packageName}", elapsedTime)
            .apply()
        
        // Clear any remaining time data since timer completed fully
        clearRemainingTime(packageName)
        
        android.util.Log.d(TAG, "Saved timer expiration info for $packageName")
        
        // Launch pause screen with timer_expired=true to show the pause flow
        handler.post {
            try {
                val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("blocked_app_package", packageName)
                    putExtra("show_lock", true)
                    putExtra("timer_expired", true)
                    putExtra("timer_state", "expired")
                }
                startActivity(pauseIntent)
                android.util.Log.d(TAG, "TIMER OFF: $packageName")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error launching pause screen for timer expiration: "+e.message, e)
            }
        }
    }

    private fun stopTimerForApp(packageName: String) {
        android.util.Log.d(TAG, "Stopping timer for $packageName")
        
        // Calculate elapsed time
        val session = appSessions[packageName]
        val elapsedTime = if (session != null) {
            val currentTime = System.currentTimeMillis()
            ((currentTime - session.startTime) / 1000).toInt()
        } else {
            0
        }
        
        // Remove timer runnable
        timerRunnables[packageName]?.let { runnable ->
            handler.removeCallbacks(runnable)
            timerRunnables.remove(packageName)
        }
        
        // Clear session data
        appSessions.remove(packageName)
        
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"
        
        prefs.edit()
            .remove(sessionStartKey)
            .remove(sessionDurationKey)
            .apply()
        
        // Save timer stop info to SharedPreferences for Flutter to read
        prefs.edit()
            .putString("timer_stopped_${packageName}", "true")
            .putInt("timer_elapsed_${packageName}", elapsedTime)
            .apply()
        
        android.util.Log.d(TAG, "Saved timer stop info for $packageName: ${elapsedTime}s")
        
        android.util.Log.d(TAG, "Timer stopped for $packageName, elapsed: ${elapsedTime}s")
    }

    private fun resetAppBlock(packageName: String) {
        // Remove from permanently blocked apps
        permanentlyBlockedApps.remove(packageName)
        
        // Clear any recent blocking flags
        recentlyBlockedApps.remove(packageName)
        
        // Clear currently paused app flag if it matches
        if (currentlyPausedApp == packageName) {
            currentlyPausedApp = null
        }
    }

    private fun permanentlyBlockApp(packageName: String) {
        android.util.Log.d(TAG, "PERMANENTLY BLOCK: Starting permanent block for $packageName")
        
        // Add to permanently blocked apps
        permanentlyBlockedApps.add(packageName)
        
        // Mark as recently blocked to prevent immediate re-blocking
        recentlyBlockedApps[packageName] = System.currentTimeMillis()
        
        // Ensure app is in blocked list
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        if (!blockedApps.contains(packageName)) {
            blockedApps.add(packageName)
            prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
            android.util.Log.d(TAG, "PERMANENTLY BLOCK: Added $packageName to blocked list")
        } else {
            android.util.Log.d(TAG, "PERMANENTLY BLOCK: $packageName already in blocked list")
        }
        
        android.util.Log.d(TAG, "PERMANENTLY BLOCK: Current blocked apps: $blockedApps")
    }

    private fun showTimerCompletedNotification(packageName: String) {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            val channelId = "timer_completed"
            
            // Create notification channel
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channel = android.app.NotificationChannel(
                    channelId,
                    "Timer Completed",
                    android.app.NotificationManager.IMPORTANCE_DEFAULT
                )
                notificationManager.createNotificationChannel(channel)
            }
            
            val notification = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                android.app.Notification.Builder(this, channelId)
                    .setContentTitle("Timer Completed")
                    .setContentText("Your session with $packageName has ended")
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setAutoCancel(true)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                android.app.Notification.Builder(this)
                    .setContentTitle("Timer Completed")
                    .setContentText("Your session with $packageName has ended")
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setAutoCancel(true)
                    .setPriority(android.app.Notification.PRIORITY_DEFAULT)
                    .build()
            }
            
            notificationManager.notify(packageName.hashCode(), notification)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error showing timer completed notification: ${e.message}", e)
        }
    }

    private fun showTimerStoppedNotification(packageName: String) {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            val channelId = "timer_stopped"
            
            // Create notification channel
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channel = android.app.NotificationChannel(
                    channelId,
                    "Timer Stopped",
                    android.app.NotificationManager.IMPORTANCE_DEFAULT
                )
                notificationManager.createNotificationChannel(channel)
            }
            
            val notification = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                android.app.Notification.Builder(this, channelId)
                    .setContentTitle("Timer Stopped")
                    .setContentText("Your session with $packageName was interrupted")
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setAutoCancel(true)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                android.app.Notification.Builder(this)
                    .setContentTitle("Timer Stopped")
                    .setContentText("Your session with $packageName was interrupted")
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setAutoCancel(true)
                    .setPriority(android.app.Notification.PRIORITY_DEFAULT)
                    .build()
            }
            
            notificationManager.notify((packageName + "_stopped").hashCode(), notification)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error showing timer stopped notification: ${e.message}", e)
        }
    }

    private fun restoreActiveTimers() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val allKeys = prefs.all.keys.filter { it.startsWith(APP_SESSION_PREFIX) }
            
            for (key in allKeys) {
                if (key.endsWith("_start")) {
                    val packageName = key.substring(APP_SESSION_PREFIX.length, key.length - 6) // Remove "_start"
                    val startTimeStr = prefs.getString(key, null)
                    val durationSeconds = prefs.getLong("${APP_SESSION_PREFIX}${packageName}_duration", 0)
                    
                    if (startTimeStr != null && durationSeconds > 0) {
                        val startTime = startTimeStr.toLongOrNull() ?: continue
                        val currentTime = System.currentTimeMillis()
                        val elapsed = currentTime - startTime
                        val remaining = (durationSeconds * 1000) - elapsed
                        
                        if (remaining > 0) {
                            // Restore the session
                            val session = AppSession(packageName, startTime, durationSeconds * 1000)
                            appSessions[packageName] = session
                            
                            // Restart the timer
                            val timerRunnable = Runnable {
                                endAppSession(packageName)
                            }
                            timerRunnables[packageName] = timerRunnable
                            handler.postDelayed(timerRunnable, remaining)
                            
                            android.util.Log.d(TAG, "Restored timer for $packageName: ${remaining}ms remaining")
                        } else {
                            // Timer has expired, clean up
                            prefs.edit()
                                .remove(key)
                                .remove("${APP_SESSION_PREFIX}${packageName}_duration")
                                .apply()
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error restoring active timers: ${e.message}", e)
        }
    }

    private fun holdAppProcess(packageName: String) {
        try {
            android.util.Log.d(TAG, "Holding app process: $packageName")
            
            // Method 1: Send the app to background using HOME intent
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(homeIntent)
            
            // Method 2: Try to suspend the process (doesn't kill, just pauses)
            try {
                val process = Runtime.getRuntime().exec(arrayOf("am", "set-inactive", packageName, "true"))
                process.waitFor()
                android.util.Log.d(TAG, "App process held: $packageName")
            } catch (e: Exception) {
                android.util.Log.d(TAG, "Could not hold process using set-inactive: ${e.message}")
            }
            
            // Method 3: Try to stop the app activity without killing the process
            try {
                val process = Runtime.getRuntime().exec(arrayOf("am", "stop-app", packageName))
                process.waitFor()
                android.util.Log.d(TAG, "App activity stopped: $packageName")
            } catch (e: Exception) {
                android.util.Log.d(TAG, "Could not stop app activity: ${e.message}")
            }
            
            // Keep a reference that this app is being held
            heldApps[packageName] = System.currentTimeMillis()
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error holding app process: ${e.message}", e)
        }
    }
    
    private fun releaseHeldApp(packageName: String) {
        try {
            android.util.Log.d(TAG, "Releasing held app: $packageName")
            
            // Re-activate the app if it was set as inactive
            try {
                val process = Runtime.getRuntime().exec(arrayOf("am", "set-inactive", packageName, "false"))
                process.waitFor()
                android.util.Log.d(TAG, "App process released: $packageName")
            } catch (e: Exception) {
                android.util.Log.d(TAG, "Could not release process using set-inactive: ${e.message}")
            }
            
            // Remove from held apps
            heldApps.remove(packageName)
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error releasing held app: ${e.message}", e)
        }
    }

    private fun forceStopApp(packageName: String) {
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
            Thread.sleep(1000)
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error force stopping $packageName: ${e.message}", e)
        }
    }

    private fun detectStartupRunningApps() {
        try {
            val currentTime = System.currentTimeMillis()
            val endTime = currentTime
            val startTime = endTime - 60000 // Look back 1 minute
            
            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
            val event = UsageEvents.Event()
            
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    val packageName = event.packageName
                    if (packageName != "com.detach.app" && packageName != packageName) {
                        startupRunningApps.add(packageName)
                        android.util.Log.d(TAG, "Detected startup app: $packageName")
                    }
                }
            }
            
            android.util.Log.d(TAG, "Startup apps detected: ${startupRunningApps.size}")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error detecting startup apps: ${e.message}", e)
        }
    }

    private fun markStartupAppsAsDetected() {
        startupAppsDetected = true
        android.util.Log.d(TAG, "Startup apps marked as detected")
    }

    private fun startMonitoring() {
        if (!isMonitoringEnabled) return
        
        val executor = Executors.newSingleThreadScheduledExecutor()
        executor.scheduleAtFixedRate({
            try {
                checkForegroundApp()
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error in monitoring loop: ${e.message}", e)
            }
        }, 0, 500, TimeUnit.MILLISECONDS) // Check every 500ms for faster response
        
        android.util.Log.d(TAG, "App monitoring started")
    }

    private fun checkForegroundApp() {
        try {
            val currentTime = System.currentTimeMillis()
            val endTime = currentTime
            val startTime = endTime - 1000 // Look back 1 second
            
            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
            val event = UsageEvents.Event()
            var foregroundApp: String? = null
            
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    foregroundApp = event.packageName
                    lastEventTime = event.timeStamp
                }
            }
            
            if (foregroundApp != null && foregroundApp != lastForegroundApp) {
                android.util.Log.d(TAG, "Foreground app changed: $lastForegroundApp -> $foregroundApp")
                
                // Special early interception for Facebook
                if (foregroundApp == "com.facebook.katana") {
                    val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                    val blockedApps = prefs.getStringSet("blocked_apps", null)
                    if (blockedApps != null && blockedApps.contains(foregroundApp)) {
                        android.util.Log.d(TAG, "Facebook detected early - preventing launch")
                        // Skip normal processing and go directly to blocked app handling
                        lastForegroundApp = foregroundApp
                        handleAppForegrounded(foregroundApp)
                        return
                    }
                }

                // If the previous foreground app had an active session, save remaining time instead of re-blocking
                if (lastForegroundApp != null && appSessions.containsKey(lastForegroundApp)) {
                    val session = appSessions[lastForegroundApp]
                    if (session != null) {
                        val currentTime = System.currentTimeMillis()
                        val elapsedTime = ((currentTime - session.startTime) / 1000).toInt()
                        val totalDuration = (session.duration / 1000).toInt()
                        val remainingSeconds = totalDuration - elapsedTime
                        
                        stopTimerForApp(lastForegroundApp!!)
                        
                        // Save remaining time for resuming later using persistent storage
                        if (remainingSeconds > 0) {
                            saveRemainingTime(lastForegroundApp!!, remainingSeconds)
                            android.util.Log.d(TAG, "User switched from $lastForegroundApp, saved remaining time: ${remainingSeconds}s")
                        } else {
                            // Timer expired, add back to blocked list
                            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                            val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                            if (!blockedApps.contains(lastForegroundApp)) {
                                blockedApps.add(lastForegroundApp!!)
                                prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                            }
                            clearRemainingTime(lastForegroundApp!!)
                            android.util.Log.d(TAG, "Timer expired for $lastForegroundApp, re-blocked")
                        }
                    }
                }

                lastForegroundApp = foregroundApp
                
                // Check if Detach is in foreground
                isDetachInForeground = (foregroundApp == "com.detach.app")
                
                if (foregroundApp == "com.detach.app") {
                    // Detach came to foreground, clear any pending launches
                    pendingAppLaunches.clear()
                    android.util.Log.d(TAG, "Detach in foreground, cleared pending launches")
                } else {
                    // Another app came to foreground
                    handleAppForegrounded(foregroundApp)
                }
            }
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error checking foreground app: ${e.message}", e)
        }
    }

    private fun handleAppForegrounded(packageName: String) {
        // Skip if this is Detach app itself
        if (packageName == "com.detach.app") {
            return
        }
        
        // Special handling for Facebook - check if it's blocked FIRST
        if (packageName == "com.facebook.katana") {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val blockedApps = prefs.getStringSet("blocked_apps", null)
            if (blockedApps != null && blockedApps.contains(packageName)) {
                android.util.Log.d(TAG, "Facebook is blocked - holding its process and showing pause screen")
                
                // Hold Facebook's process instead of killing it
                holdAppProcess(packageName)
                
                // Then show pause screen immediately
                handler.post {
                    val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK or 
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_NO_ANIMATION
                        putExtra("blocked_app_package", packageName)
                        putExtra("show_lock", true)
                        putExtra("timer_expired", false)
                        putExtra("timer_state", "normal")
                        putExtra("immediate_block", true)
                        putExtra("overlay_mode", true)
                        putExtra("hold_process", true) // Indicate we're holding the process
                    }
                    startActivity(pauseIntent)
                    currentlyPausedApp = packageName
                    lastPauseLaunchTime[packageName] = System.currentTimeMillis()
                }
                return
            }
        }
        
        // Skip if this app has an active session
        if (appSessions.containsKey(packageName)) {
            android.util.Log.d(TAG, "App $packageName has active session, allowing")
            return
        }
        
        // Check if this app has remaining timer time to resume using persistent storage
        val remainingSeconds = getRemainingTime(packageName)
        if (remainingSeconds > 0) {
            android.util.Log.d(TAG, "Resuming timer for $packageName with ${remainingSeconds}s remaining")
            
            // Start the timer with remaining time
            startTimerForApp(packageName, remainingSeconds)
            
            // Clear the remaining time data
            clearRemainingTime(packageName)
            
            return // Allow the app to open with resumed timer
        }
        
        // Check if this app was recently unblocked
        val unblockedTime = unblockedApps[packageName] ?: 0L
        val currentTime = System.currentTimeMillis()
        if ((currentTime - unblockedTime) < cooldownMillis) {
            android.util.Log.d(TAG, "App $packageName recently unblocked, allowing")
            return
        }
        
        // Check if this app is permanently blocked
        if (permanentlyBlockedApps.contains(packageName)) {
            android.util.Log.d(TAG, "App $packageName is permanently blocked")
            forceStopApp(packageName)
            return
        }
        
        // Check if Detach is already in foreground - if so, don't show pause screen
        if (isDetachInForeground) {
            android.util.Log.d(TAG, "Detach already in foreground, not showing pause screen for $packageName")
            forceStopApp(packageName)
            return
        }
        
        // Check if we're already showing pause screen for this app
        if (currentlyPausedApp == packageName) {
            android.util.Log.d(TAG, "Already showing pause screen for $packageName, skipping")
            android.util.Log.d(TAG, "This means the pause screen is currently active for this app")
            return
        }
        
        // Check if Detach is currently in foreground - if so, don't show pause screen
        if (isDetachInForeground) {
            android.util.Log.d(TAG, "Detach is in foreground, not showing pause screen for $packageName")
            return
        }
        
        // Check if this app is in startup apps and we haven't marked them as detected yet
        if (!startupAppsDetected && startupRunningApps.contains(packageName)) {
            android.util.Log.d(TAG, "App $packageName is in startup apps, skipping for now")
            return
        }
        
        // Check cooldown to prevent rapid launches
        val lastLaunchTime = lastPauseLaunchTime[packageName] ?: 0L
        if ((currentTime - lastLaunchTime) < pauseLaunchCooldownMillis) {
            android.util.Log.d(TAG, "Pause screen cooldown active for $packageName, skipping")
            return
        }
        
        // Check if this app is blocked
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val blockedApps = prefs.getStringSet("blocked_apps", null)
        android.util.Log.d(TAG, "Checking if $packageName is blocked. Blocked apps: $blockedApps")
        android.util.Log.d(TAG, "App sessions: $appSessions")
        android.util.Log.d(TAG, "Currently paused app: $currentlyPausedApp")
        android.util.Log.d(TAG, "Is Detach in foreground: $isDetachInForeground")

        if (blockedApps != null && blockedApps.contains(packageName)) {
            android.util.Log.d(TAG, "App $packageName is blocked, launching pause screen immediately")

            // Launch pause screen immediately (no splash delay like competitor)
            try {
                android.util.Log.d(TAG, "Launching pause screen for $packageName immediately...")
                val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("blocked_app_package", packageName)
                    putExtra("show_lock", true)
                    putExtra("timer_expired", false)
                    putExtra("timer_state", "normal")
                    putExtra("immediate_block", true) // Indicate immediate blocking
                    putExtra("overlay_mode", true) // Make it an overlay
                }
                startActivity(pauseIntent)
                lastPauseLaunchTime[packageName] = currentTime
                android.util.Log.d(TAG, "Pause screen launched successfully for $packageName")
                
                // Mark as currently paused only after successful launch
                currentlyPausedApp = packageName
                
                // Set a timeout to clear currentlyPausedApp after 3 seconds to prevent permanent blocking
                handler.postDelayed({
                    if (currentlyPausedApp == packageName) {
                        currentlyPausedApp = null
                        android.util.Log.d(TAG, "Cleared currentlyPausedApp for $packageName due to safety timeout")
                    }
                }, 3000) // 3 seconds safety timeout
                
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error launching pause screen: ${e.message}", e)
                // Don't set currentlyPausedApp if launch failed
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
            // Calculate remaining time using session data
            val currentTime = System.currentTimeMillis()
            val elapsedTime = ((currentTime - session.startTime) / 1000).toInt()
            val totalDuration = (session.duration / 1000).toInt()
            val remainingSeconds = totalDuration - elapsedTime
            
            // Stop the timer
            stopTimerForApp(packageName)
            
            // Save remaining time for resuming later using persistent storage
            if (remainingSeconds > 0) {
                saveRemainingTime(packageName, remainingSeconds)
                android.util.Log.d(TAG, "Saved remaining time for $packageName: ${remainingSeconds}s")
                
                // DON'T add the app back to blocked list - keep it accessible for resume
            } else {
                // Timer expired, add back to blocked list
                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                if (!blockedApps.contains(packageName)) {
                    blockedApps.add(packageName)
                    prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                }
                clearRemainingTime(packageName)
            }

            // Clear session data
            val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
            val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            prefs.edit()
                .remove(sessionStartKey)
                .remove(sessionDurationKey)
                .apply()
            
            appSessions.remove(packageName)

            // Show notification about timer stopped
            showTimerStoppedNotification(packageName)
            
            android.util.Log.d(TAG, "TIMER OFF: $packageName (backgrounded) - remaining: ${remainingSeconds}s")
            
            return
        }

        // Check cooldown to prevent rapid processing
        val lastBackgroundTime = lastBackgroundedTime[packageName] ?: 0L
        val currentTime = System.currentTimeMillis()
        if ((currentTime - lastBackgroundTime) < backgroundCooldownMillis) {
            return
        }
        lastBackgroundedTime[packageName] = currentTime

        // Check if this app was recently blocked
        val recentlyBlockedTime = recentlyBlockedApps[packageName] ?: 0L
        if ((currentTime - recentlyBlockedTime) < blockCooldownMillis) {
            return
        }

        // Check for early app close
        checkAndHandleEarlyAppClose(packageName)
    }

    private fun checkAndHandleEarlyAppClose(packageName: String) {
        val earlyCloseTime = earlyClosedApps[packageName] ?: 0L
        val currentTime = System.currentTimeMillis()
        
        if (earlyCloseTime > 0 && (currentTime - earlyCloseTime) < 5000) {
            android.util.Log.d(TAG, "Early close detected for $packageName, but not re-blocking - allowing resume")
            
            // DON'T re-add to blocked list - let user resume the timer
            // The remaining time is saved in SharedPreferences by Flutter
            
            earlyClosedApps.remove(packageName)
        }
    }

    private fun startServicePersistence() {
        // Monitor service health and restart if needed
        handler.postDelayed(object : Runnable {
            override fun run() {
                try {
                    // Check if service is still running properly
                    if (!isServiceFullyInitialized) {
                        android.util.Log.w(TAG, "Service not fully initialized, restarting monitoring")
                        startMonitoring()
                        isServiceFullyInitialized = true
                    }
                    
                    // Schedule next check
                    handler.postDelayed(this, 30000) // Check every 30 seconds
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "Error in service persistence check: ${e.message}", e)
                }
            }
        }, 30000)
    }

    override fun onCreate() {
        super.onCreate()

        serviceStartTime = System.currentTimeMillis()
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        handler = Handler(Looper.getMainLooper())

        // Clear any stale currentlyPausedApp flag on service restart
        currentlyPausedApp = null

        // Initialize service restart manager
        serviceRestartManager = ServiceRestartManager(this)
        serviceRestartManager.registerRestartReceiver()

        // Set up enhanced service persistence
        setupServiceRestart()

        // Acquire wake lock to prevent service from being killed
        acquireWakeLock()

        // Start as foreground service to prevent freezing - this must be called early
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
            addAction("com.example.detach.CLEAR_PAUSE_FLAG")
            addAction("com.example.detach.FLUTTER_APP_KILLED")
            addAction(RESTART_ACTION)
        }
        registerReceiver(resetBlockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        registerReceiver(serviceRestartReceiver, IntentFilter(RESTART_ACTION), Context.RECEIVER_NOT_EXPORTED)

        // Enhanced startup app detection - capture ALL currently running apps
        detectStartupRunningApps()
        
        // Start monitoring after a short delay to ensure everything is initialized
        handler.postDelayed({
            startMonitoring()
            isServiceFullyInitialized = true
        }, startupDelayMillis)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        
        when (action) {
            "com.example.detach.RESET_APP_BLOCK" -> {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    resetAppBlock(packageName)
                }
            }
            "com.example.detach.PERMANENTLY_BLOCK_APP" -> {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    permanentlyBlockApp(packageName)
                }
            }
            "com.example.detach.RESET_PAUSE_FLAG" -> {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    currentlyPausedApp = null
                }
            }
            "com.example.detach.PAUSE_SCREEN_CLOSED" -> {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    currentlyPausedApp = null
                }
            }
            "com.example.detach.START_APP_SESSION" -> {
                val packageName = intent.getStringExtra("package_name")
                val durationSeconds = intent.getLongExtra("duration_seconds", 0)
                if (packageName != null && durationSeconds > 0) {
                    startAppSession(packageName, durationSeconds)
                }
            }
            "com.example.detach.APP_BLOCKED" -> {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    // Mark as recently blocked to prevent immediate re-blocking
                    recentlyBlockedApps[packageName] = System.currentTimeMillis()
                }
            }
            "com.example.detach.LAUNCH_APP_WITH_TIMER" -> {
                val packageName = intent.getStringExtra("package_name")
                val durationSeconds = intent.getIntExtra("duration_seconds", 0)
                if (packageName != null && durationSeconds > 0) {
                    handleLaunchAppWithTimer(packageName, durationSeconds)
                }
            }
            "com.example.detach.TEST_PAUSE_SCREEN" -> {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    showPauseScreen(packageName)
                }
            }
            "com.example.detach.CLEAR_PAUSE_FLAG" -> {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    currentlyPausedApp = null
                } else {
                    currentlyPausedApp = null
                }
            }
        }
        
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        android.util.Log.d(TAG, "Service onDestroy called")
        
        try {
            // Release wake lock
            releaseWakeLock()
            
            // Cancel restart alarm
            restartPendingIntent?.let {
                alarmManager.cancel(it)
            }
            
            // Unregister receivers
            try {
                unregisterReceiver(resetBlockReceiver)
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error unregistering resetBlockReceiver: ${e.message}")
            }
            
            try {
                unregisterReceiver(serviceRestartReceiver)
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error unregistering serviceRestartReceiver: ${e.message}")
            }
            
            // Stop all active timers
            val activeApps = appSessions.keys.toList()
            activeApps.forEach { packageName ->
                val session = appSessions[packageName]
                if (session != null) {
                    val currentTime = System.currentTimeMillis()
                    val elapsedTime = ((currentTime - session.startTime) / 1000).toInt()
                    val totalDuration = (session.duration / 1000).toInt()
                    val remainingSeconds = totalDuration - elapsedTime
                    
                    if (remainingSeconds > 0) {
                        saveRemainingTime(packageName, remainingSeconds)
                        android.util.Log.d(TAG, "Service destroyed, saved remaining time for $packageName: ${remainingSeconds}s")
                    }
                }
            }
            
            // Schedule service restart to ensure it continues running
            setupServiceRestart()
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error in onDestroy: ${e.message}", e)
        }
    }

    private fun startForegroundService() {
        try {
            val channelId = NOTIFICATION_CHANNEL_ID
            val channelName = "Detach Service"
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            
            // Create notification channel for Android O and above
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channel = android.app.NotificationChannel(
                    channelId,
                    channelName,
                    android.app.NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Keeps Detach service running to monitor blocked apps"
                    setShowBadge(false)
                    enableLights(false)
                    enableVibration(false)
                    setSound(null, null)
                }
                notificationManager.createNotificationChannel(channel)
            }

            // Create notification with proper pending intent
            val notificationIntent = Intent(this, MainActivity::class.java)
            val pendingIntent = android.app.PendingIntent.getActivity(
                this, 0, notificationIntent, 
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )

            val notification = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                android.app.Notification.Builder(this, channelId)
                    .setContentTitle("Detach Active")
                    .setContentText("Monitoring blocked apps")
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setContentIntent(pendingIntent)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setCategory(android.app.Notification.CATEGORY_SERVICE)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                android.app.Notification.Builder(this)
                    .setContentTitle("Detach Active")
                    .setContentText("Monitoring blocked apps")
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setContentIntent(pendingIntent)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setPriority(android.app.Notification.PRIORITY_LOW)
                    .build()
            }

            // Start foreground with service type for Android 14+
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(FOREGROUND_SERVICE_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(FOREGROUND_SERVICE_ID, notification)
            }
            android.util.Log.d(TAG, "Service started as foreground service with notification")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error starting foreground service: ${e.message}", e)
        }
    }

    private fun showPauseScreen(packageName: String) {
        val currentTime = System.currentTimeMillis()
        
        // Check cooldown to prevent rapid pause screen launches
        val lastLaunchTime = lastPauseLaunchTime[packageName] ?: 0L
        if ((currentTime - lastLaunchTime) < pauseLaunchCooldownMillis) {
            return
        }
        
        // Check if app is currently paused
        if (currentlyPausedApp == packageName) {
            return
        }
        
        // Check if app is blocked
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val blockedApps = prefs.getStringSet("blocked_apps", null)
        
        if (blockedApps != null && blockedApps.contains(packageName)) {
            // Immediately force stop the app to prevent it from appearing
            forceStopApp(packageName)
            
            // Mark as currently paused
            currentlyPausedApp = packageName
            
            // Set a timeout to clear currentlyPausedApp after 30 seconds to prevent permanent blocking
            handler.postDelayed({
                if (currentlyPausedApp == packageName) {
                    currentlyPausedApp = null
                }
            }, 30000) // 30 seconds timeout
            
            handler.post {
                try {
                    val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("blocked_app_package", packageName)
                        putExtra("show_lock", true)
                        putExtra("timer_expired", false)
                        putExtra("timer_state", "normal")
                    }
                    startActivity(pauseIntent)
                    lastPauseLaunchTime[packageName] = currentTime
                    android.util.Log.d(TAG, "APP BLOCKED: $packageName")
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "Error launching pause screen: ${e.message}", e)
                    currentlyPausedApp = null
                }
            }
        }
    }

    /**
     * Acquire a partial wake lock to prevent the service from being killed
     */
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            wakeLock = powerManager.newWakeLock(
                android.os.PowerManager.PARTIAL_WAKE_LOCK,
                "Detach:AppLaunchInterceptorWakeLock"
            )
            wakeLock?.acquire(10 * 60 * 1000L) // 10 minutes timeout
            android.util.Log.d(TAG, "Wake lock acquired")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error acquiring wake lock: ${e.message}", e)
        }
    }

    /**
     * Release the wake lock
     */
    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                android.util.Log.d(TAG, "Wake lock released")
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error releasing wake lock: ${e.message}", e)
        }
    }

    /**
     * Handle task removal (when app is removed from recent tasks)
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        android.util.Log.d(TAG, "Task removed, ensuring service continues running")
        
        // Schedule service restart to ensure it continues running
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val blockedApps = prefs.getStringSet("blocked_apps", null)
        if (blockedApps != null && blockedApps.isNotEmpty()) {
            serviceRestartManager.scheduleServiceRestart()
        }
    }

    private fun isAppInForeground(packageName: String): Boolean {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val startTime = endTime - 2000 // Look back 2 seconds
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()
        var lastForegroundApp: String? = null
        var lastEventTime: Long = 0

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lastForegroundApp = event.packageName
                lastEventTime = event.timeStamp
            }
        }
        return lastForegroundApp == packageName
    }
}