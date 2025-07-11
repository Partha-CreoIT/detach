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

class PauseActivity : FlutterActivity() {

    private val CHANNEL = "com.detach.app/permissions"
    private val TAG = "PauseActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val packageName = intent.getStringExtra("blocked_app_package")
        val showLock = intent.getBooleanExtra("show_lock", true) // Default to true
        Log.d(TAG, "onCreate called with blocked package: $packageName, showLock: $showLock")
        Log.d(TAG, "Intent extras: ${intent.extras}")
        
        // Only show pause screen if properly launched with a blocked app
        if (packageName == null) {
            Log.d(TAG, "Invalid pause screen launch, finishing activity")
            finish()
            return
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine called")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "closeBothApps" -> {
                    Log.d(TAG, "closeBothApps called from PauseActivity")
                    closeBothApps()
                    result.success(null)
                }
                "goToHomeAndFinish" -> {
                    goToHomeAndFinish()
                    result.success(null)
                }
                "resetAppBlock" -> {
                    val packageName = call.argument<String>("packageName")
                    Log.d(TAG, "resetAppBlock called for: $packageName")
                    if (packageName != null) {
                        resetAppBlock(packageName)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARG", "Package name is null.", null)
                    }
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    Log.d(TAG, "launchApp called for package: $packageName")
                    if (packageName != null) {
                        launchApp(packageName)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARG", "Package name is null.", null)
                    }
                }
                "startBlockerService" -> {
                    val apps = call.argument<List<String>>("blockedApps")
                    Log.d(TAG, "startBlockerService called with apps: $apps")
                    if (apps != null) {
                        // Save to SharedPreferences
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.edit().putStringSet("blocked_apps", apps.toSet()).apply()
                        Log.d(TAG, "Saved blocked apps: $apps")
                        
                        // Start the AppLaunchInterceptor service
                        val interceptorIntent = Intent(this, AppLaunchInterceptor::class.java)
                        startService(interceptorIntent)
                        Log.d(TAG, "Started AppLaunchInterceptor service")
                        
                        result.success(null)
                    } else {
                        result.error("INVALID_ARG", "No apps provided", null)
                    }
                }
                "permanentlyBlockApp" -> {
                    val packageName = call.argument<String>("packageName")
                    Log.d(TAG, "permanentlyBlockApp called for: $packageName")
                    if (packageName != null) {
                        // Send broadcast to AppLaunchInterceptor to permanently block the app
                        val intent = Intent("com.example.detach.PERMANENTLY_BLOCK_APP")
                        intent.putExtra("package_name", packageName)
                        sendBroadcast(intent)
                        Log.d(TAG, "Sent permanent block broadcast for: $packageName")
                        
                        // Also add to blocked apps list in SharedPreferences if not already there
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf()) ?: mutableSetOf()
                        if (!blockedApps.contains(packageName)) {
                            val newBlockedApps = blockedApps.toMutableSet()
                            newBlockedApps.add(packageName)
                            prefs.edit().putStringSet("blocked_apps", newBlockedApps).apply()
                            Log.d(TAG, "Added $packageName to blocked apps list")
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

    override fun getInitialRoute(): String {
        val packageName = intent.getStringExtra("blocked_app_package")
        val route = if (packageName != null) "/pause?package=$packageName" else "/pause"
        Log.d(TAG, "getInitialRoute called, returning route: $route")
        return route
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume called")
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause called")
    }

    override fun onDestroy() {
        super.onDestroy()
        // Reset the flag in the service
        AppLaunchInterceptor.currentlyPausedApp = null
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

    fun goToHomeAndFinish() {
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
        Log.d(TAG, "Reset app block for: $packageName")
    }

    private fun launchApp(packageName: String) {
        Log.d(TAG, "Attempting to launch app: $packageName")
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            startActivity(launchIntent)
            Log.d(TAG, "Successfully launched app: $packageName")
        } else {
            Log.e(TAG, "Could not launch app: $packageName")
        }
    }
}