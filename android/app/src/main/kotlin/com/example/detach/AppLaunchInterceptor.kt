package com.example.detach

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

    companion object {
        var currentlyPausedApp: String? = null
    }
    
    private val resetBlockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.detach.RESET_APP_BLOCK") {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    permanentlyBlockedApps.remove(packageName)
                    // Temporarily disable monitoring to allow app launch
                    isMonitoringEnabled = false
                    Log.d(TAG, "Reset block for: $packageName and disabled monitoring")
                    
                    // Re-enable monitoring after 5 seconds
                    handler.postDelayed({
                        isMonitoringEnabled = true
                        Log.d(TAG, "Re-enabled monitoring")
                    }, 5000)
                }
            } else if (intent?.action == "com.example.detach.PERMANENTLY_BLOCK_APP") {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    permanentlyBlockedApps.add(packageName)
                    Log.d(TAG, "Permanently blocked: $packageName")
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "AppLaunchInterceptor created")
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        handler = Handler(Looper.getMainLooper())
        
        // Register broadcast receiver for reset block and permanent block
        val filter = IntentFilter().apply {
            addAction("com.example.detach.RESET_APP_BLOCK")
            addAction("com.example.detach.PERMANENTLY_BLOCK_APP")
        }
        registerReceiver(resetBlockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        
        startMonitoring()
    }

    private fun startMonitoring() {
        Log.d(TAG, "Starting monitoring with blocked apps: $permanentlyBlockedApps")
        Executors.newSingleThreadScheduledExecutor().scheduleAtFixedRate({
            try {
                monitorAppUsage()
            } catch (e: Exception) {
                Log.e(TAG, "Error monitoring app usage: ${e.message}")
            }
        }, 0, 10, TimeUnit.MILLISECONDS)
    }

    private fun monitorAppUsage() {
        if (!isMonitoringEnabled) {
            return
        }
        
        val currentTime = System.currentTimeMillis()
        val events = usageStatsManager.queryEvents(lastEventTime, currentTime)
        val event = UsageEvents.Event()
        
        // Log every 100th call to see if monitoring is running
        if (currentTime % 1000 < 10) {
            Log.d(TAG, "Monitoring is running, checking for events...")
        }
        
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            Log.d(TAG, "Event detected: ${event.eventType} for package: ${event.packageName}")
            
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                val packageName = event.packageName
                Log.d(TAG, "App moved to foreground: $packageName")
                if (packageName != null && packageName != "com.example.detach") {
                    handleAppLaunch(packageName)
                }
            }
        }
        lastEventTime = currentTime
    }

    private fun handleAppLaunch(packageName: String) {
        Log.d(TAG, "Checking if $packageName is blocked...")
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val blockedApps = prefs.getStringSet("blocked_apps", null)
        Log.d(TAG, "Blocked apps from prefs: $blockedApps")
        
        // Also check if this app is in the permanently blocked list
        if (permanentlyBlockedApps.contains(packageName)) {
            Log.d(TAG, "$packageName is permanently blocked, preventing launch")
            // Prevent the launch
            handler.post {
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    am.killBackgroundProcesses(packageName)
                    val homeIntent = Intent(Intent.ACTION_MAIN)
                    homeIntent.addCategory(Intent.CATEGORY_HOME)
                    homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    startActivity(homeIntent)
                } catch (e: Exception) {
                    Log.e(TAG, "Error preventing permanently blocked app launch: ${e.message}")
                }
            }
            return
        }
        
        // Only show pause if not already showing for this app
        if (blockedApps != null && blockedApps.contains(packageName)) {
            if (currentlyPausedApp == packageName) {
                Log.d(TAG, "Pause already shown for $packageName, skipping.")
                return
            }
            currentlyPausedApp = packageName
            Log.d(TAG, "Blocked app launch detected: $packageName - SHOWING PAUSE")

            handler.post {
                try {
                    val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("blocked_app_package", packageName)
                        putExtra("show_lock", true)
                    }
                    startActivity(pauseIntent)
                } catch (e: Exception) {
                    Log.e(TAG, "Error launching pause screen: ${e.message}")
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "AppLaunchInterceptor started")
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "AppLaunchInterceptor destroyed")
        try {
            unregisterReceiver(resetBlockReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }
        currentlyPausedApp = null
    }

    override fun onBind(intent: Intent?): IBinder? = null
} 