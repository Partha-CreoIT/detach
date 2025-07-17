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
    private val startupDelayMillis = 3000L // 3 seconds delay after service starts
    private val permanentlyBlockedApps = mutableSetOf<String>()
    private var isMonitoringEnabled = true
    private val unblockedApps = mutableMapOf<String, Long>()
    private val cooldownMillis = 5000L // 5 seconds
    private var lastForegroundApp: String? = null
    private val earlyClosedApps = mutableMapOf<String, Long>()
    private val recentlyBlockedApps = mutableMapOf<String, Long>()
    private val blockCooldownMillis = 3000L // 3 seconds after blocking to not show pause
    private val pauseLaunchCooldownMillis = 2000L // 2 seconds between pause launches
    private val lastPauseLaunchTime = mutableMapOf<String, Long>()
    private val lastBackgroundedTime = mutableMapOf<String, Long>()
    private val backgroundCooldownMillis = 1000L // 1 second cooldown between background events

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
        android.util.Log.d(TAG, "Starting app session for $packageName with duration: $durationSeconds seconds")

        // Cancel any existing timer for this app
        stopTimerForApp(packageName)

        // Save session data in shared preferences for persistence across app restarts
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val startTime = System.currentTimeMillis()
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"

        // Save in memory
        appSessions[packageName] = AppSession(startTime, durationSeconds, packageName)

        // Save in shared preferences for persistence
        val editor = prefs.edit()
        editor.putString(sessionStartKey, startTime.toString())
        editor.putInt(sessionDurationKey, durationSeconds)
        val success = editor.commit()

        android.util.Log.d(TAG, "Session data saved: startTime=$startTime, duration=$durationSeconds, success=$success")

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
                        // Continue timer
                        handler.postDelayed(this, 1000)
                    }
                } else {
                    android.util.Log.d(TAG, "No active session found for $packageName, stopping timer")
                }
            }
        }

        timerRunnables[packageName] = timerRunnable
        handler.postDelayed(timerRunnable, 1000)
        
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

    override fun onCreate() {
        super.onCreate()

        serviceStartTime = System.currentTimeMillis()
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        handler = Handler(Looper.getMainLooper())

        // Register broadcast receiver for all actions
        val filter = IntentFilter().apply {
            addAction("com.example.detach.RESET_APP_BLOCK")
            addAction("com.example.detach.PERMANENTLY_BLOCK_APP")
            addAction("com.example.detach.RESET_PAUSE_FLAG")
            addAction("com.example.detach.PAUSE_SCREEN_CLOSED")
            addAction("com.example.detach.START_APP_SESSION")
            addAction("com.example.detach.APP_BLOCKED")
            addAction("com.example.detach.LAUNCH_APP_WITH_TIMER")
        }
        registerReceiver(resetBlockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)

        startMonitoring()
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
                android.util.Log.d(TAG, "App moved to foreground: $packageName, lastForegroundApp: $lastForegroundApp")
                if (packageName != null) {
                    if (packageName == "com.detach.app") {
                        lastForegroundApp = packageName
                        android.util.Log.d(TAG, "Detach app launched, setting as last foreground app")
                    } else {
                        // Only handle app launch if we're not in the middle of app startup
                        if (lastForegroundApp != null) {
                            handleAppLaunch(packageName)
                        } else {
                            android.util.Log.d(TAG, "Skipping app launch check during startup for: $packageName")
                        }
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
            return
        }
        
        // Check if service just started - don't show pause screen during startup
        val currentTime = System.currentTimeMillis()
        if ((currentTime - serviceStartTime) < startupDelayMillis) {
            android.util.Log.d(TAG, "Service just started, skipping pause screen for $packageName during startup delay")
            return
        }
        
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)

        // Check cooldown first
        val unblockTime = unblockedApps[packageName]
        if (unblockTime != null) {
            val currentTime = System.currentTimeMillis()
            if ((currentTime - unblockTime) < cooldownMillis) {
                return
            } else {
                unblockedApps.remove(packageName)
            }
        }

        // Check if app was recently blocked
        val recentBlockTime = recentlyBlockedApps[packageName]
        if (recentBlockTime != null) {
            val currentTime = System.currentTimeMillis()
            if ((currentTime - recentBlockTime) < blockCooldownMillis) {
                android.util.Log.d(TAG, "App $packageName was recently blocked, not showing pause yet")
                return
            } else {
                recentlyBlockedApps.remove(packageName)
            }
        }

        // Additional check: Don't show pause screen during initial app startup
        if (lastForegroundApp == null) {
            android.util.Log.d(TAG, "No last foreground app (app startup), not showing pause for $packageName")
            return
        }

        // Check if Detach was the last foreground app - this is actually when we SHOULD show pause
        // because user is coming from Detach app to try to open a blocked app
        if (lastForegroundApp == "com.detach.app") {
            android.util.Log.d(TAG, "User coming from Detach app to open $packageName - this is correct behavior")
            // Don't return here - continue to check if app is blocked
        }

        // Check if app has an active session - if so, don't show pause screen
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionStartStr = prefs.getString(sessionStartKey, null)
        if (sessionStartStr != null) {
            android.util.Log.d(TAG, "App $packageName has active session, not showing pause screen")
            return
        }

        val blockedApps = prefs.getStringSet("blocked_apps", null)
        android.util.Log.d(TAG, "Checking if $packageName is blocked. Blocked apps: $blockedApps")

        if (blockedApps != null && blockedApps.contains(packageName)) {
            android.util.Log.d(TAG, "App $packageName is blocked, showing pause screen")

            if (currentlyPausedApp == packageName) {
                currentlyPausedApp = null
            }
            currentlyPausedApp = packageName

            handler.post {
                try {
                    // Check cooldown to prevent rapid launches
                    val lastLaunchTime = lastPauseLaunchTime[packageName] ?: 0L
                    val currentTime = System.currentTimeMillis()
                    if ((currentTime - lastLaunchTime) < pauseLaunchCooldownMillis) {
                        android.util.Log.d(TAG, "Pause screen cooldown active for $packageName, skipping")
                        return@post
                    }
                    
                    // Reset the currently paused app flag to allow new pause screen
                    currentlyPausedApp = null
                    
                    val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra("blocked_app_package", packageName)
                        putExtra("show_lock", true)
                        putExtra("timer_expired", false)
                        putExtra("timer_state", "normal")
                    }
                    startActivity(pauseIntent)
                    lastPauseLaunchTime[packageName] = currentTime
                    android.util.Log.d(TAG, "Pause screen launched for $packageName")
                } catch (e: Exception) {
                    currentlyPausedApp = null
                    android.util.Log.e(TAG, "Error launching pause screen: ${e.message}", e)
                }
            }
        } else {
            android.util.Log.d(TAG, "App $packageName is NOT blocked or blockedApps is null")
        }
    }

    private fun handleAppBackgrounded(packageName: String) {
        // Check cooldown to prevent rapid background events
        val lastBackgroundTime = lastBackgroundedTime[packageName] ?: 0L
        val currentTime = System.currentTimeMillis()
        if ((currentTime - lastBackgroundTime) < backgroundCooldownMillis) {
            android.util.Log.d(TAG, "Background cooldown active for $packageName, skipping")
            return
        }
        lastBackgroundedTime[packageName] = currentTime
        
        android.util.Log.d(TAG, "=== handleAppBackgrounded called for $packageName ===")

        // If the app was temporarily unblocked, re-block it immediately
        if (unblockedApps.containsKey(packageName)) {
            unblockedApps.remove(packageName)
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
            blockedApps.add(packageName)
            prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
            android.util.Log.d(TAG, "Re-blocked temporarily unblocked app: $packageName")
        }

        // Check if this app has an active session and was closed early
        // Add a small delay to prevent false early close detection
        handler.postDelayed({
            checkAndHandleEarlyAppClose(packageName)
        }, 2000) // 2 second delay to allow for normal app switching
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