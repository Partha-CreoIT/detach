package com.detach.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BootReceiver automatically restarts the AppLaunchInterceptor service
 * after device reboot to ensure app blocking continues to work.
 */
class BootReceiver : BroadcastReceiver() {
    private val TAG = "BootReceiver"

    override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.d(TAG, "Boot completed, restarting AppLaunchInterceptor service")
                restartBlockerService(context)
            }
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.d(TAG, "App updated, restarting AppLaunchInterceptor service")
                restartBlockerService(context)
            }
            Intent.ACTION_PACKAGE_REPLACED -> {
                val packageName = intent.data?.schemeSpecificPart
                if (packageName == context?.packageName) {
                    Log.d(TAG, "App replaced, restarting AppLaunchInterceptor service")
                    restartBlockerService(context)
                }
            }
            "android.intent.action.QUICKBOOT_POWERON" -> {
                Log.d(TAG, "Quick boot completed, restarting AppLaunchInterceptor service")
                restartBlockerService(context)
            }
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                Log.d(TAG, "HTC quick boot completed, restarting AppLaunchInterceptor service")
                restartBlockerService(context)
            }
        }
    }

    private fun restartBlockerService(context: Context?) {
        context?.let {
            try {
                // Check if there are any blocked apps before starting service
                val prefs = it.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val blockedApps = prefs.getStringSet("blocked_apps", null)
                
                if (blockedApps != null && blockedApps.isNotEmpty()) {
                    Log.d(TAG, "Found ${blockedApps.size} blocked apps, starting service")
                    
                    // Start the AppLaunchInterceptor service
                    val serviceIntent = Intent(it, AppLaunchInterceptor::class.java)
                    
                    // Use startForegroundService for Android 8.0+ to avoid crashes
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        it.startForegroundService(serviceIntent)
                    } else {
                        it.startService(serviceIntent)
                    }
                    
                    Log.d(TAG, "AppLaunchInterceptor service started successfully after boot")
                } else {
                    Log.d(TAG, "No blocked apps found, skipping service start")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error restarting AppLaunchInterceptor service: ${e.message}", e)
            }
        }
    }
} 