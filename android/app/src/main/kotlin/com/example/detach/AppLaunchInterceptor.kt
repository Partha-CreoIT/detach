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
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "AppLaunchInterceptor created")
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        handler = Handler(Looper.getMainLooper())
        
        // Register broadcast receiver for reset block
        val filter = IntentFilter("com.example.detach.RESET_APP_BLOCK")
        registerReceiver(resetBlockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        
        startMonitoring()
    }

    private fun startMonitoring() {
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
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                val packageName = event.packageName
                if (packageName != null && packageName != "com.example.detach") {
                    handleAppLaunch(packageName)
                }
            }
        }
        lastEventTime = currentTime
    }

    private fun handleAppLaunch(packageName: String) {
        // Check if this app is permanently blocked (user clicked "I don't want to open")
        if (permanentlyBlockedApps.contains(packageName)) {
            Log.d(TAG, "$packageName is permanently blocked. Ignoring.")
            return
        }
        
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val blockedApps = prefs.getStringSet("blocked_apps", null)
        if (blockedApps != null && blockedApps.contains(packageName)) {
            Log.d(TAG, "Blocked app launch detected: $packageName - PREVENTING LAUNCH")
            permanentlyBlockedApps.add(packageName)
            handler.post {
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    am.killBackgroundProcesses(packageName)
                    try {
                        val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "am force-stop $packageName"))
                        process.waitFor()
                        Log.d(TAG, "Force stopped $packageName using shell command")
                    } catch (e: Exception) {
                        Log.d(TAG, "Could not force stop $packageName using shell command: ${e.message}")
                    }
                    val homeIntent = Intent(Intent.ACTION_MAIN)
                    homeIntent.addCategory(Intent.CATEGORY_HOME)
                    homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    startActivity(homeIntent)
                    Thread.sleep(50)
                    val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("blocked_app_package", packageName)
                    }
                    startActivity(pauseIntent)
                } catch (e: Exception) {
                    Log.e(TAG, "Error preventing app launch: ${e.message}")
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
    }

    override fun onBind(intent: Intent?): IBinder? = null
} 