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
    private val earlyCloseCooldownMillis = 10000L // 10 seconds cooldown after early close

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
                }
            }
        }
    }

    private fun startAppSession(packageName: String, durationSeconds: Int) {
        // Save session data in shared preferences for persistence across app restarts
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val startTime = System.currentTimeMillis()

        // Save in memory
        appSessions[packageName] = AppSession(startTime, durationSeconds)

        // Save in shared preferences for persistence
        prefs.edit()
            .putLong("${APP_SESSION_PREFIX}${packageName}_start", startTime)
            .putInt("${APP_SESSION_PREFIX}${packageName}_duration", durationSeconds)
            .apply()

        Log.d(TAG, "Started app session for $packageName, duration: $durationSeconds seconds")
    }

    private fun checkAndHandleEarlyAppClose(packageName: String) {
        // Check if this app has an active session
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val startTime = prefs.getLong("${APP_SESSION_PREFIX}${packageName}_start", 0)

        if (startTime > 0) {
            val durationSeconds = prefs.getInt("${APP_SESSION_PREFIX}${packageName}_duration", 0)
            val currentTime = System.currentTimeMillis()
            val elapsedSeconds = (currentTime - startTime) / 1000

            Log.d(
                TAG,
                "App $packageName closed. Elapsed time: $elapsedSeconds seconds, Total duration: $durationSeconds seconds"
            )

            // If app was closed before timer finished
            if (elapsedSeconds < durationSeconds) {
                Log.d(TAG, "App $packageName closed early! Re-blocking app.")

                // Add back to blocked apps
                val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet()
                    ?: mutableSetOf()
                if (!blockedApps.contains(packageName)) {
                    blockedApps.add(packageName)
                    prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                }
            }

            // Clear the session data
            prefs.edit()
                .remove("${APP_SESSION_PREFIX}${packageName}_start")
                .remove("${APP_SESSION_PREFIX}${packageName}_duration")
                .apply()

            // Also remove from memory
            appSessions.remove(packageName)
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
            Log.d(TAG, "Event detected: ${event.eventType} for package: ${event.packageName}")

            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                val packageName = event.packageName
                Log.d(
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
                    Log.d(TAG, "App moved to background: $packageName")
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
        
        // Check early close cooldown
        val earlyCloseTime = earlyClosedApps[packageName]
        if (earlyCloseTime != null) {
            val currentTime = System.currentTimeMillis()
            if ((currentTime - earlyCloseTime) < earlyCloseCooldownMillis) {
                Log.d(TAG, "App $packageName was closed early recently, not showing pause screen yet")
                return
            } else {
                earlyClosedApps.remove(packageName)
            }
        }
        
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
        }

        // Check if this app has an active session and was closed early
        checkAndHandleEarlyAppClose(packageName)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

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