package com.example.detach

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

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.detach.app/permissions"
    private val TAG = "MainActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate called with intent: ${intent?.action}, extras: ${intent?.extras}")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine called")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsagePermission" -> {
                    val hasPermission = hasUsageAccess()
                    Log.d(TAG, "checkUsagePermission: $hasPermission")
                    result.success(hasPermission)
                }
                "checkAccessibilityPermission" -> {
                    val hasPermission = isAccessibilityServiceEnabled()
                    Log.d(TAG, "checkAccessibilityPermission: $hasPermission")
                    result.success(hasPermission)
                }
                "checkOverlayPermission" -> {
                    val hasPermission = Settings.canDrawOverlays(this)
                    Log.d(TAG, "checkOverlayPermission: $hasPermission")
                    result.success(hasPermission)
                }
                "checkBatteryOptimization" -> {
                    val hasPermission = isIgnoringBatteryOptimizations()
                    Log.d(TAG, "checkBatteryOptimization: $hasPermission")
                    result.success(hasPermission)
                }
                "openUsageSettings" -> {
                    openUsageAccessSettings()
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
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
                    Log.d(TAG, "startBlockerService called with apps: $apps")
                    if (apps != null) {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.edit().putStringSet("blocked_apps", apps.toSet()).apply()
                        Log.d(TAG, "Saved blocked apps: $apps")
                        
                        // Verify the save worked
                        val savedApps = prefs.getStringSet("blocked_apps", null)
                        Log.d(TAG, "Verified saved apps: $savedApps")
                        
                        // Start the AppLaunchInterceptor service
                        val interceptorIntent = Intent(this, AppLaunchInterceptor::class.java)
                        startService(interceptorIntent)
                        Log.d(TAG, "Started AppLaunchInterceptor service")
                        
                        // Also check if service is running
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                        val runningServices = am.getRunningServices(Integer.MAX_VALUE)
                        val isServiceRunning = runningServices.any { it.service.className == "com.example.detach.AppLaunchInterceptor" }
                        Log.d(TAG, "AppLaunchInterceptor service running: $isServiceRunning")
                    } else {
                        Log.e(TAG, "No apps provided to startBlockerService")
                    }
                    result.success(null)
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    Log.d(TAG, "launchApp called for package: $packageName")
                    if (packageName != null) {
                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                        if (launchIntent != null) {
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            Log.e(TAG, "Could not launch app: $packageName")
                            result.error("UNAVAILABLE", "Could not launch app.", null)
                        }
                    } else {
                        result.error("INVALID_ARG", "Package name is null.", null)
                    }
                }
                "closeBothApps" -> {
                    Log.d(TAG, "closeBothApps called")
                    closeBothApps()
                    result.success(null)
                }
                "resetAppBlock" -> {
                    val packageName = call.argument<String>("packageName")
                    Log.d(TAG, "resetAppBlock called for: $packageName")
                    if (packageName != null) {
                        resetAppBlock(packageName)
                    }
                    result.success(null)
                }
                "permanentlyBlockApp" -> {
                    val packageName = call.argument<String>("packageName")
                    Log.d(TAG, "permanentlyBlockApp called for: $packageName")
                    if (packageName != null) {
                        permanentlyBlockApp(packageName)
                    }
                    result.success(null)
                }
                "isBlockerServiceRunning" -> {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    val runningServices = am.getRunningServices(Integer.MAX_VALUE)
                    val isRunning = runningServices.any { it.service.className == "com.example.detach.AppLaunchInterceptor" }
                    Log.d(TAG, "Checking if AppLaunchInterceptor is running: $isRunning")
                    result.success(isRunning)
                }
                "getBlockedApps" -> {
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val blockedApps = prefs.getStringSet("blocked_apps", null)
                    val appsList = blockedApps?.toList() ?: emptyList()
                    Log.d(TAG, "Getting blocked apps: $appsList")
                    result.success(appsList)
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
        
        Log.d(TAG, "getInitialRoute called - showLock: $showLock, lockedPackage: $lockedPackage")
        
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

    private fun isAccessibilityServiceEnabled(): Boolean {
        val service = "$packageName/${MyAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        return enabledServices?.contains(service) == true
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
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
        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    private fun closeBothApps() {
        try {
            Log.d(TAG, "Starting closeBothApps")
            
            // Get the ActivityManager
            val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            
            // Get recent tasks to find the blocked app
            val recentTasks = am.getRecentTasks(10, android.app.ActivityManager.RECENT_WITH_EXCLUDED)
            
            // Find and close the blocked app
            for (task in recentTasks) {
                val baseIntent = task.baseIntent
                val packageName = baseIntent.component?.packageName
                
                if (packageName != null && packageName != this.packageName) {
                    Log.d(TAG, "Found app to close: $packageName")
                    
                    // Try multiple methods to force stop the app
                    try {
                        // Method 1: Kill background processes
                        am.killBackgroundProcesses(packageName)
                        Log.d(TAG, "Killed background processes for: $packageName")
                        
                        // Method 2: Try to force stop using shell command (requires root or system app)
                        try {
                            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "am force-stop $packageName"))
                            process.waitFor()
                            Log.d(TAG, "Force stopped $packageName using shell command")
                        } catch (e: Exception) {
                            Log.d(TAG, "Could not force stop $packageName using shell command: ${e.message}")
                        }
                        
                        // Method 3: Try to clear recent tasks by restarting the launcher
                        try {
                            val homeIntent = Intent(Intent.ACTION_MAIN)
                            homeIntent.addCategory(Intent.CATEGORY_HOME)
                            homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(homeIntent)
                            Log.d(TAG, "Sent home intent to clear recent tasks")
                        } catch (e: Exception) {
                            Log.d(TAG, "Could not send home intent: ${e.message}")
                        }
                        
                    } catch (e: Exception) {
                        Log.e(TAG, "Error killing app $packageName: ${e.message}")
                    }
                }
            }
            
            // Add a small delay to ensure the blocked app is killed
            Thread.sleep(500)
            
            // Close the current app (Detach)
            Log.d(TAG, "Closing current app")
            finishAndRemoveTask()
            
            // Force stop completely
            finishAffinity()
            android.os.Process.killProcess(android.os.Process.myPid())
            
        } catch (e: Exception) {
            Log.e(TAG, "Error closing apps: ${e.message}")
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
        Log.d(TAG, "Reset app block for: $packageName")
    }

    private fun permanentlyBlockApp(packageName: String) {
        // Send broadcast to AppLaunchInterceptor to permanently block the app
        val intent = Intent("com.example.detach.PERMANENTLY_BLOCK_APP")
        intent.putExtra("package_name", packageName)
        sendBroadcast(intent)
        Log.d(TAG, "Permanently blocked app: $packageName")
    }
}