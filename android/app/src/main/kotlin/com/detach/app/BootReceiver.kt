package com.detach.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    private val TAG = "BootReceiver"
    
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Boot completed, checking if we need to start AppLaunchInterceptor service")
            
            context?.let { ctx ->
                try {
                    // Check if there are any blocked apps to monitor
                    val prefs = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val blockedApps = prefs.getStringSet("blocked_apps", null)
                    
                    if (blockedApps != null && blockedApps.isNotEmpty()) {
                        Log.d(TAG, "Found ${blockedApps.size} blocked apps, starting AppLaunchInterceptor service")
                        
                        // Start the service
                        val serviceIntent = Intent(ctx, AppLaunchInterceptor::class.java)
                        ctx.startService(serviceIntent)
                        
                        Log.d(TAG, "AppLaunchInterceptor service started on boot")
                    } else {
                        Log.d(TAG, "No blocked apps found, not starting service on boot")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error starting service on boot: ${e.message}", e)
                }
            }
        }
    }
} 