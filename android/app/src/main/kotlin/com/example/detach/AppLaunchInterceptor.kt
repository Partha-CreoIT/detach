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
    private val unblockedApps = mutableMapOf<String, Long>()
    private val cooldownMillis = 5000L // 5 seconds
    private var lastForegroundApp: String? = null
    companion object {
        var currentlyPausedApp: String? = null
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
            }
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
                
                if (packageName != null && packageName != "com.example.detach") {
                    handleAppLaunch(packageName)
                    lastForegroundApp = packageName
                }
            }
            // Detect when an allowed app leaves the foreground
            if (event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND) {
                val packageName = event.packageName
                if (packageName != null && packageName != "com.example.detach") {
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