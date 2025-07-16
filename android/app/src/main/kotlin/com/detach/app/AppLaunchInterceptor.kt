package com.detach.app

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.IBinder
import android.util.Log
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class AppLaunchInterceptor : Service() {
    private val TAG = "AppLaunchInterceptor"
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var handler: Handler
    private var lastEventTime = 0L
    private val permanentlyBlockedApps = mutableSetOf<String>()
    private var isMonitoringEnabled = true
    private val unblockedApps = mutableMapOf<String, Long>()
    private val cooldownMillis = 5000L // 5 seconds
    private var lastForegroundApp: String? = null
    private val earlyClosedApps = mutableMapOf<String, Long>()
    // private val earlyCloseCooldownMillis = 1000L // 1 second cooldown after early close to prevent rapid re-triggering

    // Session tracking for timer-based app usage
    private data class AppSession(
        val startTime: Long,
        val durationSeconds: Int
    )

    private val appSessions = mutableMapOf<String, AppSession>()

    companion object {
        var currentlyPausedApp: String? = null
        const val APP_SESSION_PREFIX = "app_session_"
        const val APP_SESSION_DURATION_SUFFIX = "_duration"
    }

    private val resetBlockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.detach.RESET_APP_BLOCK") {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    permanentlyBlockedApps.remove(packageName)
                    // Add to unblocked apps with current timestamp
                    unblockedApps[packageName] = System.currentTimeMillis()

                }
            } else if (intent?.action == "com.example.detach.PERMANENTLY_BLOCK_APP") {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    permanentlyBlockedApps.add(packageName)

                }
            } else if (intent?.action == "com.example.detach.RESET_PAUSE_FLAG") {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null && currentlyPausedApp == packageName) {
                    currentlyPausedApp = null

                }
            } else if (intent?.action == "com.example.detach.START_APP_SESSION") {
                val packageName = intent.getStringExtra("package_name")
                val durationSeconds = intent.getIntExtra("duration_seconds", 0)
                Log.d(TAG, "Received START_APP_SESSION broadcast: package=$packageName, duration=$durationSeconds")
                if (packageName != null && durationSeconds > 0) {
                    // Start tracking this app session
                    startAppSession(packageName, durationSeconds)
                } else {
                    Log.e(TAG, "Invalid START_APP_SESSION parameters: package=$packageName, duration=$durationSeconds")
                }
            }
        }
    }

    private fun startAppSession(packageName: String, durationSeconds: Int) {
        Log.d(TAG, "=== startAppSession called for $packageName, duration: $durationSeconds seconds ===")

        // Save session data in shared preferences for persistence across app restarts
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val startTime = System.currentTimeMillis()
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"

        Log.d(TAG, "Session keys: $sessionStartKey, $sessionDurationKey")
        Log.d(TAG, "Start time: $startTime")

        // Save in memory
        appSessions[packageName] = AppSession(startTime, durationSeconds)
        Log.d(TAG, "Saved session in memory")

        // Save in shared preferences for persistence
        val editor = prefs.edit()
        editor.putString(sessionStartKey, startTime.toString())
        editor.putInt(sessionDurationKey, durationSeconds)
        val success = editor.commit() // Use commit() instead of apply() for immediate persistence

        Log.d(TAG, "Saved session to SharedPreferences, success: $success")

        // Verify the save worked
        val savedStartTime = prefs.getString(sessionStartKey, null)
        val savedDuration = prefs.getInt(sessionDurationKey, -1)
        Log.d(TAG, "Verification - saved startTime: $savedStartTime, saved duration: $savedDuration")

        Log.d(TAG, "=== startAppSession completed for $packageName ===")
    }

    private fun checkAndHandleEarlyAppClose(packageName: String) {
        Log.d(TAG, "=== checkAndHandleEarlyAppClose called for $packageName ===")

        // Check if this app has an active session
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"

        Log.d(TAG, "Looking for session keys: $sessionStartKey, $sessionDurationKey")

        // Check all keys in SharedPreferences to debug
        val allKeys = prefs.all
        Log.d(TAG, "All SharedPreferences keys: ${allKeys.keys}")

        val startTimeStr = prefs.getString(sessionStartKey, null)
        Log.d(TAG, "Found startTimeStr: $startTimeStr")

        if (startTimeStr != null) {
            val startTime = startTimeStr.toLongOrNull() ?: 0L
            val durationSeconds = prefs.getInt(sessionDurationKey, 0)
            val currentTime = System.currentTimeMillis()
            val elapsedSeconds = (currentTime - startTime) / 1000

            Log.d(TAG, "Session details for $packageName:")
            Log.d(TAG, "  - Start time: $startTime")
            Log.d(TAG, "  - Current time: $currentTime")
            Log.d(TAG, "  - Duration seconds: $durationSeconds")
            Log.d(TAG, "  - Elapsed seconds: $elapsedSeconds")

            // If app was closed before timer finished
            if (elapsedSeconds < durationSeconds) {
                Log.d(TAG, "*** APP $packageName CLOSED EARLY! RE-BLOCKING APP ***")

                // Add back to blocked apps
                val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet()
                    ?: mutableSetOf()
                Log.d(TAG, "Current blocked apps before adding: $blockedApps")

                if (!blockedApps.contains(packageName)) {
                    blockedApps.add(packageName)
                    Log.d(TAG, "Added $packageName to blocked apps: $blockedApps")
                    prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                    Log.d(TAG, "Saved blocked apps to SharedPreferences")
                } else {
                    Log.d(TAG, "$packageName was already in blocked apps list")
                }

                // Add to early closed apps list for cooldown management - removed
                // earlyClosedApps[packageName] = System.currentTimeMillis()
            } else {
                Log.d(TAG, "App $packageName was closed after timer finished, no re-blocking needed")
            }

            // Clear the session data
            Log.d(TAG, "Clearing session data for $packageName")
            prefs.edit()
                .remove(sessionStartKey)
                .remove(sessionDurationKey)
                .apply()
            Log.d(TAG, "Session data cleared")

            // Also remove from memory
            appSessions.remove(packageName)
            Log.d(TAG, "Removed from memory appSessions")
        } else {
            Log.d(TAG, "No active session found for $packageName")
        }

        Log.d(TAG, "=== checkAndHandleEarlyAppClose completed for $packageName ===")
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "=== AppLaunchInterceptor onCreate ===")

        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        handler = Handler(Looper.getMainLooper())

        // Register broadcast receiver for reset block and permanent block
        val filter = IntentFilter().apply {
            addAction("com.example.detach.RESET_APP_BLOCK")
            addAction("com.example.detach.PERMANENTLY_BLOCK_APP")
            addAction("com.example.detach.RESET_PAUSE_FLAG")
            addAction("com.example.detach.START_APP_SESSION")
        }
        Log.d(TAG, "Registering broadcast receiver with actions: ${filter.actionsIterator().asSequence().toList()}")
        registerReceiver(resetBlockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        Log.d(TAG, "Broadcast receiver registered successfully")

        startMonitoring()
        Log.d(TAG, "=== AppLaunchInterceptor onCreate completed ===")
    }

    private fun startMonitoring() {

        Executors.newSingleThreadScheduledExecutor().scheduleAtFixedRate({
            try {
                monitorAppUsage()
            } catch (e: Exception) {

            }
        }, 0, 10, TimeUnit.MILLISECONDS)
    }

    private fun monitorAppUsage() {
        val currentTime = System.currentTimeMillis()
        val events = usageStatsManager.queryEvents(lastEventTime, currentTime)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            Log.d(TAG, "Event detected: ${event.eventType} for package: ${event.packageName}")

            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                val packageName = event.packageName
                Log.d(
                    TAG,
                    "App moved to foreground: $packageName, lastForegroundApp: $lastForegroundApp"
                )
                if (packageName != null && packageName != "com.detach.app") {
                    Log.d(TAG, "Calling handleAppLaunch for foreground app: $packageName")
                    handleAppLaunch(packageName)
                    lastForegroundApp = packageName
                }
            }
            // Detect when an allowed app leaves the foreground
            if (event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND) {
                val packageName = event.packageName
                if (packageName != null && packageName != "com.detach.app") {
                    Log.d(TAG, "App moved to background: $packageName")
                    Log.d(TAG, "Calling handleAppBackgrounded for background app: $packageName")
                    handleAppBackgrounded(packageName)
                }
            }
        }
        lastEventTime = currentTime
    }

    private fun handleAppLaunch(packageName: String) {
        Log.d(TAG, "=== handleAppLaunch called for $packageName ===")

        // Check cooldown first
        val unblockTime = unblockedApps[packageName]
        if (unblockTime != null) {
            val currentTime = System.currentTimeMillis()
            if ((currentTime - unblockTime) < cooldownMillis) {
                Log.d(TAG, "App $packageName is in cooldown period, skipping")
                return
            } else {
                Log.d(TAG, "App $packageName cooldown expired, removing from unblockedApps")
                unblockedApps.remove(packageName)
            }
        }

        // Check early close cooldown - removed to allow immediate re-blocking
        // val earlyCloseTime = earlyClosedApps[packageName]
        // if (earlyCloseTime != null) {
        //     val currentTime = System.currentTimeMillis()
        //     if ((currentTime - earlyCloseTime) < earlyCloseCooldownMillis) {
        //         Log.d(TAG, "App $packageName was closed early recently, not showing pause screen yet")
        //         return
        //     } else {
        //         earlyClosedApps.remove(packageName)
        //     }
        // }

        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val blockedApps = prefs.getStringSet("blocked_apps", null)

        Log.d(TAG, "Blocked apps from SharedPreferences: $blockedApps")
        Log.d(TAG, "Checking if $packageName is in blocked apps: ${blockedApps?.contains(packageName)}")

        // Only show pause if not already showing for this app and not in cooldown
        if (blockedApps != null && blockedApps.contains(packageName)) {
            Log.d(TAG, "*** APP $packageName IS BLOCKED, SHOWING PAUSE SCREEN ***")

            // Reset currentlyPausedApp if it's been more than 10 seconds since last pause
            // This allows the pause screen to show again for the same app after a reasonable delay
            if (currentlyPausedApp == packageName) {
                Log.d(TAG, "Resetting currentlyPausedApp from $currentlyPausedApp to null")
                // For now, let's allow showing the pause screen again immediately
                // This will help with the issue where the pause screen doesn't show
                currentlyPausedApp = null
            }
            currentlyPausedApp = packageName
            Log.d(TAG, "Set currentlyPausedApp to $packageName")

            handler.post {
                try {
                    Log.d(TAG, "Launching PauseActivity for $packageName")
                    val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("blocked_app_package", packageName)
                        putExtra("show_lock", true)
                    }
                    startActivity(pauseIntent)
                    Log.d(TAG, "PauseActivity launched successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Error launching PauseActivity: ${e.message}")
                    // Reset the flag if there was an error launching the pause screen
                    currentlyPausedApp = null
                }
            }
        } else {
            Log.d(TAG, "App $packageName is not blocked, allowing launch")
        }

        Log.d(TAG, "=== handleAppLaunch completed for $packageName ===")
    }

    private fun handleAppBackgrounded(packageName: String) {
        Log.d(TAG, "=== handleAppBackgrounded called for $packageName ===")

        // If the app was temporarily unblocked, re-block it immediately
        if (unblockedApps.containsKey(packageName)) {
            Log.d(TAG, "App $packageName was temporarily unblocked, re-blocking immediately")
            unblockedApps.remove(packageName)
            // Add back to blocked apps in SharedPreferences
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val blockedApps =
                prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
            blockedApps.add(packageName)
            prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
            Log.d(TAG, "Re-blocked $packageName in SharedPreferences")
        } else {
            Log.d(TAG, "App $packageName was not in unblockedApps list")
        }

        // Check if this app has an active session and was closed early
        Log.d(TAG, "Calling checkAndHandleEarlyAppClose for $packageName")
        checkAndHandleEarlyAppClose(packageName)

        Log.d(TAG, "=== handleAppBackgrounded completed for $packageName ===")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "=== onStartCommand called ===")

        if (intent != null) {
            val action = intent.action
            Log.d(TAG, "Received intent with action: $action")

            if (action == "com.example.detach.START_APP_SESSION") {
                val packageName = intent.getStringExtra("package_name")
                val durationSeconds = intent.getIntExtra("duration_seconds", 0)
                Log.d(TAG, "Direct service call - START_APP_SESSION: package=$packageName, duration=$durationSeconds")

                if (packageName != null && durationSeconds > 0) {
                    startAppSession(packageName, durationSeconds)
                }
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()

        try {
            unregisterReceiver(resetBlockReceiver)
        } catch (e: Exception) {

        }
        currentlyPausedApp = null
    }

    override fun onBind(intent: Intent?): IBinder? = null
}