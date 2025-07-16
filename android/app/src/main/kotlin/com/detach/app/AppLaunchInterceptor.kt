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
                if (packageName != null && durationSeconds > 0) {
                    // Start tracking this app session
                    startAppSession(packageName, durationSeconds)
                } else {
                }
            }
        }
    }

    private fun startAppSession(packageName: String, durationSeconds: Int) {
        
        // Save session data in shared preferences for persistence across app restarts
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val startTime = System.currentTimeMillis()
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"


        // Save in memory
        appSessions[packageName] = AppSession(startTime, durationSeconds)

        // Save in shared preferences for persistence
        val editor = prefs.edit()
        editor.putString(sessionStartKey, startTime.toString())
        editor.putInt(sessionDurationKey, durationSeconds)
        val success = editor.commit() // Use commit() instead of apply() for immediate persistence

        
        // Verify the save worked
        val savedStartTime = prefs.getString(sessionStartKey, null)
        val savedDuration = prefs.getInt(sessionDurationKey, -1)
        
    }

    private fun checkAndHandleEarlyAppClose(packageName: String) {
        
        // Check if this app has an active session
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
        val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"
        
        
        // Check all keys in SharedPreferences to debug
        val allKeys = prefs.all
        
        val startTimeStr = prefs.getString(sessionStartKey, null)

        if (startTimeStr != null) {
            val startTime = startTimeStr.toLongOrNull() ?: 0L
            val durationSeconds = prefs.getInt(sessionDurationKey, 0)
            val currentTime = System.currentTimeMillis()
            val elapsedSeconds = (currentTime - startTime) / 1000


            // If app was closed before timer finished
            if (elapsedSeconds < durationSeconds) {

                // Add back to blocked apps
                val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet()
                    ?: mutableSetOf()
                
                if (!blockedApps.contains(packageName)) {
                    blockedApps.add(packageName)
                    prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                } else {
                }
                
                // Add to early closed apps list for cooldown management - removed
                // earlyClosedApps[packageName] = System.currentTimeMillis()
            } else {
            }

            // Clear the session data
            prefs.edit()
                .remove(sessionStartKey)
                .remove(sessionDurationKey)
                .apply()

            // Also remove from memory
            appSessions.remove(packageName)
        } else {
        }
        
    }

    override fun onCreate() {
        super.onCreate()

        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        handler = Handler(Looper.getMainLooper())
        
        // Register broadcast receiver for reset block and permanent block
        val filter = IntentFilter().apply {
            addAction("com.example.detach.RESET_APP_BLOCK")
            addAction("com.example.detach.PERMANENTLY_BLOCK_APP")
            addAction("com.example.detach.RESET_PAUSE_FLAG")
            addAction("com.example.detach.START_APP_SESSION")
        }
        registerReceiver(resetBlockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        
        startMonitoring()
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

            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                val packageName = event.packageName
                    TAG,
                    "App moved to foreground: $packageName, lastForegroundApp: $lastForegroundApp"
                )
                if (packageName != null && packageName != "com.detach.app") {
                    handleAppLaunch(packageName)
                    lastForegroundApp = packageName
                }
            }
            // Detect when an allowed app leaves the foreground
            if (event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND) {
                val packageName = event.packageName
                if (packageName != null && packageName != "com.detach.app") {
                    handleAppBackgrounded(packageName)
                }
            }
        }
        lastEventTime = currentTime
    }

    private fun handleAppLaunch(packageName: String) {

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
        
        // Check early close cooldown - removed to allow immediate re-blocking
        // val earlyCloseTime = earlyClosedApps[packageName]
        // if (earlyCloseTime != null) {
        //     val currentTime = System.currentTimeMillis()
        //     if ((currentTime - earlyCloseTime) < earlyCloseCooldownMillis) {
        //         return
        //     } else {
        //         earlyClosedApps.remove(packageName)
        //     }
        // }
        
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val blockedApps = prefs.getStringSet("blocked_apps", null)
        

        // Only show pause if not already showing for this app and not in cooldown
        if (blockedApps != null && blockedApps.contains(packageName)) {
            
            // Reset currentlyPausedApp if it's been more than 10 seconds since last pause
            // This allows the pause screen to show again for the same app after a reasonable delay
            if (currentlyPausedApp == packageName) {
                // For now, let's allow showing the pause screen again immediately
                // This will help with the issue where the pause screen doesn't show
                currentlyPausedApp = null
            }
            currentlyPausedApp = packageName

            handler.post {
                try {
                    val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("blocked_app_package", packageName)
                        putExtra("show_lock", true)
                    }
                    startActivity(pauseIntent)
                } catch (e: Exception) {
                    // Reset the flag if there was an error launching the pause screen
                    currentlyPausedApp = null
                }
            }
        } else {
        }
        
    }

    private fun handleAppBackgrounded(packageName: String) {
        
        // If the app was temporarily unblocked, re-block it immediately
        if (unblockedApps.containsKey(packageName)) {
            unblockedApps.remove(packageName)
            // Add back to blocked apps in SharedPreferences
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val blockedApps =
                prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
            blockedApps.add(packageName)
            prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
        } else {
        }

        // Check if this app has an active session and was closed early
        checkAndHandleEarlyAppClose(packageName)
        
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        
        if (intent != null) {
            val action = intent.action
            
            if (action == "com.example.detach.START_APP_SESSION") {
                val packageName = intent.getStringExtra("package_name")
                val durationSeconds = intent.getIntExtra("duration_seconds", 0)
                
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