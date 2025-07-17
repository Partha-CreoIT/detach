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
                            putExtra("packageName", packageName)
                            putExtra("durationSeconds", durationSeconds)
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
                "testPauseScreen" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        Log.d(TAG, "Testing pause screen for $packageName")
                        
                        // Send to AppLaunchInterceptor to test pause screen
                        val testIntent = Intent(this, AppLaunchInterceptor::class.java).apply {
                            action = "com.example.detach.TEST_PAUSE_SCREEN"
                            putExtra("packageName", packageName)
                        }
                        startService(testIntent)
                        
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "Package name is null", null)
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

    private fun startBlockerService() {
        try {
            Log.d(TAG, "Starting AppLaunchInterceptor service...")
            val serviceIntent = Intent(this, AppLaunchInterceptor::class.java)
            startService(serviceIntent)
            Log.d(TAG, "AppLaunchInterceptor service started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting AppLaunchInterceptor service: ${e.message}", e)
        }
    }
}