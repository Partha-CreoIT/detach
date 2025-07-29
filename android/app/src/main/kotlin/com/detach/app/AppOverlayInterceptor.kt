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
import android.util.Log

class AppOverlayInterceptor : Service() {
    private val TAG = "AppOverlayInterceptor"
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var handler: Handler
    private var lastEventTime = 0L
    private var isMonitoringEnabled = true
    private var lastForegroundApp: String? = null
    private val blockedApps = mutableSetOf<String>()
    private val appSplashDelays = mutableMapOf<String, Long>()
    private val recentlyLaunchedApps = mutableMapOf<String, Long>()
    private val launchCooldownMillis = 3000L
    
    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "detach_overlay_service_channel"
        private const val FOREGROUND_SERVICE_ID = 1002
    }

    private val appLaunchReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.example.detach.APP_LAUNCHED" -> {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null) {
                        handleAppLaunch(packageName)
                    }
                }
            }
        }
    }

    private fun handleAppLaunch(packageName: String) {
        val currentTime = System.currentTimeMillis()
        
        // Check if this app was recently launched to avoid duplicate handling
        val lastLaunchTime = recentlyLaunchedApps[packageName] ?: 0L
        if ((currentTime - lastLaunchTime) < launchCooldownMillis) {
            Log.d(TAG, "App $packageName recently launched, skipping")
            return
        }
        
        recentlyLaunchedApps[packageName] = currentTime
        
        // Check if this app is blocked
        if (blockedApps.contains(packageName)) {
            Log.d(TAG, "Blocked app $packageName launched, scheduling overlay")
            
            // Get the splash delay for this app (common 800ms for all apps)
            val splashDelay = appSplashDelays[packageName] ?: 800L
            
            // Schedule the overlay after the app's splash screen
            handler.postDelayed({
                showFlutterOverlay(packageName)
            }, splashDelay)
        }
    }

    private fun showFlutterOverlay(packageName: String) {
        try {
            Log.d(TAG, "Showing Flutter overlay for $packageName")
            
            // Launch the Flutter app as an overlay (don't close the blocked app)
            val flutterIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("show_lock", true)
                putExtra("locked_package", packageName)
                putExtra("overlay_mode", true)
            }
            
            startActivity(flutterIntent)
            Log.d(TAG, "Flutter overlay launched for $packageName")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error showing Flutter overlay: ${e.message}", e)
        }
    }

    private fun startMonitoring() {
        if (!isMonitoringEnabled) return
        
        val executor = Executors.newSingleThreadScheduledExecutor()
        executor.scheduleAtFixedRate({
            try {
                checkForegroundApp()
            } catch (e: Exception) {
                Log.e(TAG, "Error in monitoring loop: ${e.message}", e)
            }
        }, 0, 500, TimeUnit.MILLISECONDS)
        
        Log.d(TAG, "App overlay monitoring started")
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
                Log.d(TAG, "Foreground app changed: $lastForegroundApp -> $foregroundApp")
                lastForegroundApp = foregroundApp
                
                // Check if this is a blocked app that just came to foreground
                if (blockedApps.contains(foregroundApp)) {
                    Log.d(TAG, "Blocked app $foregroundApp came to foreground")
                    handleAppLaunch(foregroundApp)
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking foreground app: ${e.message}", e)
        }
    }

    override fun onCreate() {
        super.onCreate()
        
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        handler = Handler(Looper.getMainLooper())
        
        // Load blocked apps from SharedPreferences
        loadBlockedApps()
        
        // Set up splash delays for common apps (reduced for faster response)
        setupSplashDelays()
        
        // Register broadcast receiver
        val filter = IntentFilter().apply {
            addAction("com.example.detach.APP_LAUNCHED")
        }
        registerReceiver(appLaunchReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        
        // Start monitoring
        startMonitoring()
        
        Log.d(TAG, "AppOverlayInterceptor service created")
    }

    private fun loadBlockedApps() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val blockedAppsSet = prefs.getStringSet("blocked_apps", null)
            if (blockedAppsSet != null) {
                blockedApps.clear()
                blockedApps.addAll(blockedAppsSet)
                Log.d(TAG, "Loaded blocked apps: $blockedApps")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading blocked apps: ${e.message}", e)
        }
    }

    private fun setupSplashDelays() {
        // Set common splash delay for all apps (in milliseconds)
        // This allows any app to show its splash screen briefly before overlay
        val commonDelay = 800L
        
        // Apply common delay to all known apps
        val knownApps = listOf(
            "com.instagram.android", "com.facebook.katana", "com.whatsapp",
            "com.google.android.youtube", "com.spotify.music", "com.netflix.mediaclient",
            "com.discord", "com.reddit.frontpage", "com.snapchat.android", "com.twitter.android"
        )
        
        knownApps.forEach { app ->
            appSplashDelays[app] = commonDelay
        }
        
        Log.d(TAG, "Common splash delay configured: ${commonDelay}ms for all apps")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        
        when (action) {
            "com.example.detach.RELOAD_BLOCKED_APPS" -> {
                loadBlockedApps()
            }
            "com.example.detach.APP_LAUNCHED" -> {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    handleAppLaunch(packageName)
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
        Log.d(TAG, "AppOverlayInterceptor service destroyed")
        
        try {
            unregisterReceiver(appLaunchReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}", e)
        }
    }
} 