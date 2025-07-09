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
                    if (apps != null) {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.edit().putStringSet("blocked_apps", apps.toSet()).apply()
                        Log.d(TAG, "Saved blocked apps: $apps")
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
}