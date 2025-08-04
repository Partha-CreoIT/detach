package com.detach.app
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
// AppOverlayInterceptor import removed - using immediate blocking
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.detach.app/permissions"
    private val TAG = "MainActivity"
    private lateinit var methodChannel: MethodChannel
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Ensure the AppLaunchInterceptor service is running
        startBlockerService()
        
        GeneratedPluginRegistrant.registerWith(FlutterEngine(this))
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsagePermission" -> {
                    val hasPermission = hasUsageAccess()

                    result.success(hasPermission)
                }
                "checkOverlayPermission" -> {
                    val hasPermission = Settings.canDrawOverlays(this)

                    result.success(hasPermission)
                }
                "checkBatteryOptimization" -> {
                    val hasPermission = isIgnoringBatteryOptimizations()

                    result.success(hasPermission)
                }
                "openUsageSettings" -> {
                    openUsageAccessSettings()
                    result.success(null)
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(null)
                }
                "openBatterySettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(null)
                }
                "startBlockerService" -> {
                    val apps = call.argument<List<String>>("blockedApps")
                    Log.d(TAG, "Received blocked apps: $apps")

                    if (apps != null) {
                        val prefs =
                            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        
                        // Store as both StringSet (for native compatibility) and StringList (for Flutter compatibility)
                        prefs.edit().apply {
                            putStringSet("blocked_apps", apps.toSet())
                            putString("blocked_apps_list", apps.joinToString(","))
                            apply()
                        }

                        // Verify the save worked
                        val savedApps = prefs.getStringSet("blocked_apps", null)
                        Log.d(TAG, "Saved blocked apps as set: $savedApps")

                        // Start the AppLaunchInterceptor service
                        val interceptorIntent = Intent(this, AppLaunchInterceptor::class.java)
                        startService(interceptorIntent)

                        // Also check if service is running
                        val am =
                            getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                        val runningServices = am.getRunningServices(Integer.MAX_VALUE)
                        val isServiceRunning =
                            runningServices.any { it.service.className == "com.detach.app.AppLaunchInterceptor" }
                        Log.d(TAG, "AppLaunchInterceptor service running: $isServiceRunning")

                    } else {
                        Log.e(TAG, "Blocked apps list is null")
                    }
                    result.success(null)
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    Log.d(TAG, "Attempting to launch app: $packageName")

                    if (packageName != null) {
                        try {
                            // First check if the app is actually installed and user-facing
                            val appInfo = try {
                                packageManager.getApplicationInfo(packageName, 0)
                            } catch (e: Exception) {
                                null
                            }
                            
                            Log.d(TAG, "App info for $packageName: enabled=${appInfo?.enabled}, system=${appInfo?.flags?.and(android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0}")
                            
                            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                            Log.d(TAG, "Launch intent for $packageName: $launchIntent")
                            
                            if (launchIntent != null) {
                                // Add flags to ensure proper app launch
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                
                                startActivity(launchIntent)
                                Log.d(TAG, "Successfully launched app: $packageName")
                                result.success(true)
                            } else {
                                Log.e(TAG, "Launch intent is null for package: $packageName")
                                // Try alternative method - check if app is installed
                                val appInfoCheck = try {
                                    packageManager.getApplicationInfo(packageName, 0)
                                } catch (e: Exception) {
                                    null
                                }
                                
                                if (appInfoCheck != null) {
                                    Log.d(TAG, "App is installed but no launch intent, trying alternative method")
                                    // Try to open app info page as fallback
                                    val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                    intent.data = android.net.Uri.parse("package:$packageName")
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(intent)
                                    result.error("NO_LAUNCH_INTENT", "App installed but cannot be launched directly", null)
                                } else {
                                    Log.e(TAG, "App not installed: $packageName")
                                    result.error("NOT_INSTALLED", "App is not installed.", null)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error launching app $packageName: ${e.message}", e)
                            result.error("LAUNCH_ERROR", "Error launching app: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARG", "Package name is null.", null)
                    }
                }
                "closeBothApps" -> {

                    closeBothApps()
                    result.success(null)
                }
                "resetAppBlock" -> {
                    val packageName = call.argument<String>("packageName")

                    if (packageName != null) {
                        resetAppBlock(packageName)
                    }
                    result.success(null)
                }
                "permanentlyBlockApp" -> {
                    val packageName = call.argument<String>("packageName")

                    if (packageName != null) {
                        permanentlyBlockApp(packageName)
                    }
                    result.success(null)
                }
                "resetPauseFlag" -> {
                    val packageName = call.argument<String>("packageName")
                    Log.d(TAG, "Resetting pause flag for ${packageName ?: "all apps"}")
                    
                    // Send to AppLaunchInterceptor to reset pause flag
                    val resetIntent = Intent(this, AppLaunchInterceptor::class.java).apply {
                        action = "com.example.detach.RESET_PAUSE_FLAG"
                        if (packageName != null) {
                            putExtra("package_name", packageName)
                        }
                    }
                    startService(resetIntent)
                    
                    result.success(true)
                }
                "forceShowPauseScreen" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        Log.d(TAG, "Force showing pause screen for $packageName")
                        
                        // Force launch pause screen
                        val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                            putExtra("blocked_app_package", packageName)
                            putExtra("show_lock", true)
                            putExtra("timer_expired", false)
                            putExtra("timer_state", "normal")
                            putExtra("overlay_mode", true)
                        }
                        startActivity(pauseIntent)
                        
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "Package name is null", null)
                    }
                }
                "isBlockerServiceRunning" -> {
                    val am =
                        getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    val runningServices = am.getRunningServices(Integer.MAX_VALUE)
                    val isRunning =
                        runningServices.any { it.service.className == "com.detach.app.AppLaunchInterceptor" }

                    result.success(isRunning)
                }
                "getBlockedApps" -> {
                    val prefs =
                        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val blockedApps = prefs.getStringSet("blocked_apps", null)
                    val appsList = blockedApps?.toList() ?: emptyList()

                    result.success(appsList)
                }
                "closeApp" -> {
                    // This will close the Flutter activity and remove the task from recents
                    finishAndRemoveTask()
                    result.success(null)
                }
                "goToHomeAndFinish" -> {
                    // Go to home screen and finish the current activity
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(homeIntent)
                    finishAndRemoveTask()
                    result.success(null)
                }
                "startAppSession" -> {
                    val packageName = call.argument<String>("packageName")
                    val durationSeconds = call.argument<Int>("durationSeconds")
                    
                    if (packageName != null && durationSeconds != null) {
                        // Send session data to AppLaunchInterceptor
                        val sessionIntent = Intent(this, AppLaunchInterceptor::class.java).apply {
                            action = "com.example.detach.START_APP_SESSION"
                            putExtra("packageName", packageName)
                            putExtra("durationSeconds", durationSeconds)
                        }
                        startService(sessionIntent)
                    }
                    result.success(null)
                }
                "launchAppWithTimer" -> {
                    val packageName = call.argument<String>("packageName")
                    val durationSeconds = call.argument<Int>("durationSeconds")
                    
                    if (packageName != null && durationSeconds != null) {
                        Log.d(TAG, "Launching app $packageName with timer for $durationSeconds seconds")
                        
                        // Send to AppLaunchInterceptor to handle timer and launch
                        val launchIntent = Intent(this, AppLaunchInterceptor::class.java).apply {
                            action = "com.example.detach.LAUNCH_APP_WITH_TIMER"
                            putExtra("package_name", packageName)
                            putExtra("duration_seconds", durationSeconds)
                        }
                        startService(launchIntent)
                        
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "Package name or duration is null", null)
                    }
                }
                "notifyAppBlocked" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        notifyAppBlocked(packageName)
                    }
                    result.success(null)
                }
                "notifyAppKilled" -> {
                    notifyAppKilled()
                    result.success(null)
                }
                "testPauseScreen" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        Log.d(TAG, "Testing pause screen for $packageName")
                        
                        // Send to AppLaunchInterceptor to test pause screen
                        val testIntent = Intent(this, AppLaunchInterceptor::class.java).apply {
                            action = "com.example.detach.TEST_PAUSE_SCREEN"
                            putExtra("package_name", packageName)
                        }
                        startService(testIntent)
                        
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "Package name is null", null)
                    }
                }
                "clearPauseFlag" -> {
                    val packageName = call.argument<String>("packageName")
                    Log.d(TAG, "Clearing pause flag for ${packageName ?: "all apps"}")
                    
                    // Send to AppLaunchInterceptor to clear pause flag
                    val clearIntent = Intent(this, AppLaunchInterceptor::class.java).apply {
                        action = "com.example.detach.CLEAR_PAUSE_FLAG"
                        if (packageName != null) {
                            putExtra("package_name", packageName)
                        }
                    }
                    startService(clearIntent)
                    
                    result.success(true)
                }
                "forceRestartBlockerService" -> {
                    forceRestartBlockerService()
                    result.success(null)
                }
                "testOverlayMode" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        Log.d(TAG, "Testing overlay mode for $packageName")
                        
                        // Test the overlay functionality
                        val overlayIntent = Intent(this, AppOverlayInterceptor::class.java).apply {
                            action = "com.example.detach.APP_LAUNCHED"
                            putExtra("package_name", packageName)
                        }
                        startService(overlayIntent)
                        
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "Package name is null", null)
                    }
                }
                "minimizeAppToBackground" -> {
                    Log.d(TAG, "Minimizing app to background")
                    try {
                        // Go to home screen
                        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(homeIntent)
                        
                        // Finish the current activity
                        finishAndRemoveTask()
                        
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error minimizing app: ${e.message}", e)
                        result.error("MINIMIZE_ERROR", "Error minimizing app: ${e.message}", null)
                    }
                }
                "goToHomeAndFinish" -> {
                    Log.d(TAG, "Going to home and finishing")
                    try {
                        // Go to home screen
                        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(homeIntent)
                        
                        // Finish the current activity
                        finishAndRemoveTask()
                        
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error going to home and finishing: ${e.message}", e)
                        result.error("HOME_FINISH_ERROR", "Error going to home and finishing: ${e.message}", null)
                    }
                }
                "checkServiceHealth" -> {
                    val healthInfo = checkServiceHealth()
                    result.success(healthInfo)
                }
                "getCurrentForegroundApp" -> {
                    try {
                        val currentApp = getCurrentForegroundApp()
                        result.success(currentApp)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting current foreground app: ${e.message}", e)
                        result.error("FOREGROUND_APP_ERROR", "Error getting current foreground app: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    override fun getInitialRoute(): String {
        val showLock = intent.getBooleanExtra("show_lock", false)
        val lockedPackage = intent.getStringExtra("locked_package")

        return if (showLock && lockedPackage != null) {
            "/pause?package=$lockedPackage"
        } else {
            "/"
        }
    }
    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }
    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }
    
    private fun getCurrentForegroundApp(): String? {
        return try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            val tasks = am.getRunningTasks(1)
            if (tasks.isNotEmpty()) {
                tasks[0].topActivity?.packageName
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting current foreground app: ${e.message}", e)
            null
        }
    }
    private fun openUsageAccessSettings() {
        // Unfortunately, there's no direct way to grant usage access like battery optimization
        // We have to send the user to the system settings
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }
    private fun openOverlaySettings() {
        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        intent.data = android.net.Uri.parse("package:$packageName")
        startActivity(intent)
    }
    private fun openBatteryOptimizationSettings() {
        // Request direct battery optimization exception
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            intent.data = android.net.Uri.parse("package:$packageName")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to settings screen if direct request fails
            val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            fallbackIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(fallbackIntent)
        }
    }
    private fun closeBothApps() {
        try {

            // Get the ActivityManager
            val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            // Get recent tasks to find the blocked app
            val recentTasks =
                am.getRecentTasks(10, android.app.ActivityManager.RECENT_WITH_EXCLUDED)
            // Find and close the blocked app
            for (task in recentTasks) {
                val baseIntent = task.baseIntent
                val packageName = baseIntent.component?.packageName
                if (packageName != null && packageName != this.packageName) {

                    // Try multiple methods to force stop the app
                    try {
                        // Method 1: Kill background processes
                        am.killBackgroundProcesses(packageName)

                        // Method 2: Try to force stop using shell command (requires root or system app)
                        try {
                            val process = Runtime.getRuntime()
                                .exec(arrayOf("su", "-c", "am force-stop $packageName"))
                            process.waitFor()

                        } catch (e: Exception) {
                            Log.d(
                                TAG,
                                "Could not force stop $packageName using shell command: ${e.message}"
                            )
                        }
                        // Method 3: Try to clear recent tasks by restarting the launcher
                        try {
                            val homeIntent = Intent(Intent.ACTION_MAIN)
                            homeIntent.addCategory(Intent.CATEGORY_HOME)
                            homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(homeIntent)

                        } catch (e: Exception) {

                        }
                    } catch (e: Exception) {

                    }
                }
            }
            // Add a small delay to ensure the blocked app is killed
            Thread.sleep(500)
            // Close the current app (Detach)

            finishAndRemoveTask()
            // Force stop completely
            finishAffinity()
            android.os.Process.killProcess(android.os.Process.myPid())
        } catch (e: Exception) {

            // Even if there's an error, try to close the current app
            finishAndRemoveTask()
            finishAffinity()
        }
    }
    private fun resetAppBlock(packageName: String) {
        // Send broadcast to AppLaunchInterceptor to reset the block
        val intent = Intent("com.example.detach.RESET_APP_BLOCK")
        intent.putExtra("package_name", packageName)
        sendBroadcast(intent)

    }
    private fun permanentlyBlockApp(packageName: String) {
        // Send broadcast to AppLaunchInterceptor to permanently block the app
        val intent = Intent("com.example.detach.PERMANENTLY_BLOCK_APP")
        intent.putExtra("package_name", packageName)
        sendBroadcast(intent)

    }

    private fun notifyAppBlocked(packageName: String) {
        // Send broadcast to AppLaunchInterceptor to notify that an app was blocked
        val intent = Intent("com.example.detach.APP_BLOCKED")
        intent.putExtra("package_name", packageName)
        sendBroadcast(intent)
    }

    private fun notifyAppKilled() {
        // Send broadcast to AppLaunchInterceptor to notify that Flutter app is being killed
        val intent = Intent("com.example.detach.FLUTTER_APP_KILLED")
        sendBroadcast(intent)
    }

    private fun startBlockerService() {
        try {
            Log.d(TAG, "Starting AppLaunchInterceptor service...")
            val serviceIntent = Intent(this, AppLaunchInterceptor::class.java)
            startService(serviceIntent)
            Log.d(TAG, "AppLaunchInterceptor service started")
            
            // Note: AppOverlayInterceptor removed - using immediate blocking instead
        } catch (e: Exception) {
            Log.e(TAG, "Error starting services: ${e.message}", e)
        }
    }

    private fun forceRestartBlockerService() {
        try {
            Log.d(TAG, "Force restarting AppLaunchInterceptor service...")
            
            // Stop the current service
            val stopIntent = Intent(this, AppLaunchInterceptor::class.java)
            stopService(stopIntent)
            
            // Wait a moment for the service to stop
            Thread.sleep(1000)
            
            // Start the service again
            val startIntent = Intent(this, AppLaunchInterceptor::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(startIntent)
            } else {
                startService(startIntent)
            }
            
            Log.d(TAG, "AppLaunchInterceptor service force restarted")
        } catch (e: Exception) {
            Log.e(TAG, "Error force restarting AppLaunchInterceptor service: ${e.message}", e)
        }
    }

    private fun checkServiceHealth(): Map<String, Any> {
        val healthInfo = mutableMapOf<String, Any>()
        
        try {
            // Check if service is running
            val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            val runningServices = am.getRunningServices(Integer.MAX_VALUE)
            val isRunning = runningServices.any { 
                it.service.className == "com.detach.app.AppLaunchInterceptor" 
            }
            healthInfo["isRunning"] = isRunning
            
            // Check permissions
            val hasUsageAccess = hasUsageAccess()
            val hasOverlayPermission = Settings.canDrawOverlays(this)
            val hasBatteryOptimization = isIgnoringBatteryOptimizations()
            
            healthInfo["hasUsageAccess"] = hasUsageAccess
            healthInfo["hasOverlayPermission"] = hasOverlayPermission
            healthInfo["hasBatteryOptimization"] = hasBatteryOptimization
            healthInfo["hasPermissions"] = hasUsageAccess && hasOverlayPermission && hasBatteryOptimization
            
            // Check if there are blocked apps
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val blockedApps = prefs.getStringSet("blocked_apps", null)
            val hasBlockedApps = blockedApps != null && blockedApps.isNotEmpty()
            healthInfo["hasBlockedApps"] = hasBlockedApps
            healthInfo["blockedAppsCount"] = blockedApps?.size ?: 0
            
            // Check if service is persistent (has wake lock, etc.)
            healthInfo["isPersistent"] = isRunning && hasBatteryOptimization
            
            Log.d(TAG, "Service health check completed: $healthInfo")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking service health: ${e.message}", e)
            healthInfo["error"] = e.message ?: "Unknown error"
        }
        
        return healthInfo
    }
}