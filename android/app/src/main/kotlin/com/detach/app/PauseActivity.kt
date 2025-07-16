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
class PauseActivity : FlutterActivity() {
    private val CHANNEL = "com.detach.app/permissions"
    private val TAG = "PauseActivity"
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val packageName = intent.getStringExtra("blocked_app_package")
        val showLock = intent.getBooleanExtra("show_lock", true) // Default to true




        // Check if we should actually show the PauseActivity
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val blockedApps = prefs.getStringSet("blocked_apps", null)
        val isAppBlocked = packageName != null && blockedApps != null && blockedApps.contains(packageName)


        // Only show pause screen if properly launched with a blocked app
        // and if showLock is true (user is trying to open the app)
        if (packageName == null || !showLock || !isAppBlocked) {

            finish()
            return
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "closeBothApps" -> {

                    closeBothApps()
                    result.success(null)
                }
                "goToHomeAndFinish" -> {
                    goToHomeAndFinish()
                    result.success(null)
                }
                "closeApp" -> {
                    closeApp()
                    result.success(null)
                }
                "resetAppBlock" -> {
                    val packageName = call.argument<String>("packageName")

                    if (packageName != null) {
                        resetAppBlock(packageName)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARG", "Package name is null.", null)
                    }
                }
                "resetPauseFlag" -> {
                    val packageName = call.argument<String>("packageName")

                    if (packageName != null) {
                        resetPauseFlag(packageName)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARG", "Package name is null.", null)
                    }
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")

                    if (packageName != null) {
                        launchApp(packageName)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARG", "Package name is null.", null)
                    }
                }
                "startAppSession" -> {
                    val packageName = call.argument<String>("packageName")
                    val durationSeconds = call.argument<Int>("durationSeconds") ?: 0

                    if (packageName != null && durationSeconds > 0) {
                        Log.d(TAG, "Method channel startAppSession: package=$packageName, duration=$durationSeconds")

                        // Method 1: Try broadcast
                        startAppSession(packageName, durationSeconds)

                        // Method 2: Direct service call
                        try {
                            val serviceIntent = Intent(this, AppLaunchInterceptor::class.java)
                            serviceIntent.action = "com.example.detach.START_APP_SESSION"
                            serviceIntent.putExtra("package_name", packageName)
                            serviceIntent.putExtra("duration_seconds", durationSeconds)
                            startService(serviceIntent)
                            Log.d(TAG, "Direct service call sent for startAppSession")
                        } catch (e: Exception) {
                            Log.e(TAG, "Error in direct service call: ${e.message}")
                        }

                        result.success(null)
                    } else {
                        result.error("INVALID_ARG", "Invalid package name or duration", null)
                    }
                }
                "startBlockerService" -> {
                    val apps = call.argument<List<String>>("blockedApps")

                    if (apps != null) {
                        // Save to SharedPreferences
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.edit().putStringSet("blocked_apps", apps.toSet()).apply()

                        // Start the AppLaunchInterceptor service
                        val interceptorIntent = Intent(this, AppLaunchInterceptor::class.java)
                        startService(interceptorIntent)

                        result.success(null)
                    } else {
                        result.error("INVALID_ARG", "No apps provided", null)
                    }
                }
                "permanentlyBlockApp" -> {
                    val packageName = call.argument<String>("packageName")
                    val isAdminBlock = call.argument<Boolean>("isAdminBlock") ?: false

                    if (packageName != null) {
                        // Send broadcast to AppLaunchInterceptor to permanently block the app
                        val intent = Intent("com.example.detach.PERMANENTLY_BLOCK_APP")
                        intent.putExtra("package_name", packageName)
                        intent.putExtra("is_admin_block", isAdminBlock)
                        sendBroadcast(intent)

                        // Also add to blocked apps list in SharedPreferences if not already there
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf()) ?: mutableSetOf()
                        if (!blockedApps.contains(packageName)) {
                            val newBlockedApps = blockedApps.toMutableSet()
                            newBlockedApps.add(packageName)
                            prefs.edit().putStringSet("blocked_apps", newBlockedApps).apply()

                        }
                        result.success(null)
                    } else {
                        result.error("INVALID_ARG", "Package name is null.", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startAppSession(packageName: String, durationSeconds: Int) {
        Log.d(TAG, "=== PauseActivity startAppSession called for $packageName, duration: $durationSeconds seconds ===")

        // Only send direct service call, avoid multiple calls
        try {
            val serviceIntent = Intent(this, AppLaunchInterceptor::class.java)
            serviceIntent.action = "com.example.detach.START_APP_SESSION"
            serviceIntent.putExtra("package_name", packageName)
            serviceIntent.putExtra("duration_seconds", durationSeconds)
            startService(serviceIntent)
            Log.d(TAG, "Service intent sent for startAppSession")
        } catch (e: Exception) {
            Log.e(TAG, "Error in service call: ${e.message}")
        }

        Log.d(TAG, "=== PauseActivity startAppSession completed for $packageName ===")
    }

    override fun getInitialRoute(): String {
        val packageName = intent.getStringExtra("blocked_app_package")
        val route = if (packageName != null) "/pause?package=$packageName" else "/pause"

        return route
    }
    override fun onResume() {
        super.onResume()

    }
    override fun onPause() {
        super.onPause()

    }
    override fun onDestroy() {
        super.onDestroy()
        // Reset the flag in the service
        AppLaunchInterceptor.currentlyPausedApp = null
    }
    private fun closeBothApps() {
        try {

            // Reset the pause flag since the user is taking action
            val packageName = intent.getStringExtra("blocked_app_package")
            if (packageName != null) {
                resetPauseFlag(packageName)
            }
            // Get the ActivityManager
            val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            // Get recent tasks to find the blocked app
            val recentTasks = am.getRecentTasks(10, android.app.ActivityManager.RECENT_WITH_EXCLUDED)
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
                            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "am force-stop $packageName"))
                            process.waitFor()

                        } catch (e: Exception) {

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
    fun goToHomeAndFinish() {
        // Reset the pause flag since the user is taking action
        val packageName = intent.getStringExtra("blocked_app_package")
        if (packageName != null) {
            resetPauseFlag(packageName)
        }
        val homeIntent = Intent(Intent.ACTION_MAIN)
        homeIntent.addCategory(Intent.CATEGORY_HOME)
        homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(homeIntent)
        finish()
    }
    private fun resetAppBlock(packageName: String) {
        // Send broadcast to AppLaunchInterceptor to reset the block
        val intent = Intent("com.example.detach.RESET_APP_BLOCK")
        intent.putExtra("package_name", packageName)
        sendBroadcast(intent)

    }
    private fun resetPauseFlag(packageName: String) {
        // Send broadcast to AppLaunchInterceptor to reset the pause flag
        val intent = Intent("com.example.detach.RESET_PAUSE_FLAG")
        intent.putExtra("package_name", packageName)
        sendBroadcast(intent)

    }
    private fun launchApp(packageName: String) {

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            startActivity(launchIntent)

        } else {

        }
    }

    private fun closeApp() {
        try {
            Log.d(TAG, "=== closeApp called ===")
            
            // Reset the pause flag since we're closing
            val packageName = intent.getStringExtra("blocked_app_package")
            if (packageName != null) {
                resetPauseFlag(packageName)
            }
            
            // Close the current Flutter activity and remove from recents
            finishAndRemoveTask()
            // Force stop completely
            finishAffinity()
            android.os.Process.killProcess(android.os.Process.myPid())
            
            Log.d(TAG, "=== closeApp completed ===")
        } catch (e: Exception) {
            Log.e(TAG, "Error in closeApp: ${e.message}")
            // Even if there's an error, try to close the current app
            try {
                finishAndRemoveTask()
                finishAffinity()
            } catch (e2: Exception) {
                Log.e(TAG, "Error in fallback closeApp: ${e2.message}")
            }
        }
    }
}