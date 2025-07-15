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
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.detach.app/permissions"
    private val TAG = "MainActivity"
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
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

                    if (apps != null) {
                        val prefs =
                            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.edit().putStringSet("blocked_apps", apps.toSet()).apply()

                        // Verify the save worked
                        val savedApps = prefs.getStringSet("blocked_apps", null)

                        // Start the AppLaunchInterceptor service
                        val interceptorIntent = Intent(this, AppLaunchInterceptor::class.java)
                        startService(interceptorIntent)

                        // Also check if service is running
                        val am =
                            getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                        val runningServices = am.getRunningServices(Integer.MAX_VALUE)
                        val isServiceRunning =
                            runningServices.any { it.service.className == "com.example.detach.AppLaunchInterceptor" }

                    } else {

                    }
                    result.success(null)
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")

                    if (packageName != null) {
                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                        if (launchIntent != null) {
                            startActivity(launchIntent)
                            result.success(true)
                        } else {

                            result.error("UNAVAILABLE", "Could not launch app.", null)
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
                        runningServices.any { it.service.className == "com.example.detach.AppLaunchInterceptor" }

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
}