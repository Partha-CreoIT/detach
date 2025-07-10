package com.example.detach

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class AppBlockerService : Service() {
    
    private val TAG = "AppBlockerService"
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var scheduledExecutor: ScheduledExecutorService
    private lateinit var handler: Handler
    private var lastEventTime = 0L
    private val unblockedApps = mutableMapOf<String, Long>()
    private val cooldownMillis = 5000L // 5 seconds
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "AppBlockerService created")
        
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        scheduledExecutor = Executors.newScheduledThreadPool(1)
        handler = Handler(Looper.getMainLooper())
        
        startMonitoring()
    }
    
    private fun startMonitoring() {
        scheduledExecutor.scheduleAtFixedRate({
            try {
                monitorAppUsage()
            } catch (e: Exception) {
                Log.e(TAG, "Error monitoring app usage: ${e.message}")
            }
        }, 0, 100, TimeUnit.MILLISECONDS) // Check every 100ms
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
                }
            }
        }
        
        lastEventTime = currentTime
    }
    
    private fun handleAppLaunch(packageName: String) {
        val currentTime = System.currentTimeMillis()
        
        // Check cooldown
        val unblockTime = unblockedApps[packageName]
        if (unblockTime != null) {
            if ((currentTime - unblockTime) < cooldownMillis) {
                Log.d(TAG, "$packageName is in cooldown. Ignoring.")
                return
            } else {
                Log.d(TAG, "$packageName cooldown expired.")
                unblockedApps.remove(packageName)
            }
        }
        
        // Check if app is blocked
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val blockedApps = prefs.getStringSet("blocked_apps", null)
        
        if (blockedApps != null && blockedApps.contains(packageName)) {
            Log.d(TAG, "Blocked app detected: $packageName")
            
            // Add to cooldown
            unblockedApps[packageName] = currentTime
            
            // Launch pause activity on main thread
            handler.post {
                try {
                    // Go to home screen first
                    val homeIntent = Intent(Intent.ACTION_MAIN)
                    homeIntent.addCategory(Intent.CATEGORY_HOME)
                    homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    startActivity(homeIntent)
                    
                    // Small delay
                    Thread.sleep(100)
                    
                    // Launch pause activity
                    val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("blocked_app_package", packageName)
                    }
                    startActivity(pauseIntent)
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Error launching pause activity: ${e.message}")
                }
            }
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "AppBlockerService started")
        return START_STICKY // Restart service if killed
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "AppBlockerService destroyed")
        scheduledExecutor.shutdown()
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}