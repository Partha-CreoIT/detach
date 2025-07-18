package com.detach.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log

/**
 * ServiceRestartManager handles automatic restart of the AppLaunchInterceptor service
 * when it gets killed by the system or Activity Manager.
 */
class ServiceRestartManager(private val context: Context) {
    private val TAG = "ServiceRestartManager"
    private val RESTART_ACTION = "com.detach.app.RESTART_SERVICE"
    private val RESTART_DELAY_MS = 5000L // 5 seconds delay before restart
    
    private var alarmManager: AlarmManager? = null
    private var restartReceiver: BroadcastReceiver? = null
    private var isRegistered = false

    init {
        alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        setupRestartReceiver()
    }

    private fun setupRestartReceiver() {
        restartReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == RESTART_ACTION) {
                    Log.d(TAG, "Received restart broadcast, starting AppLaunchInterceptor service")
                    restartService()
                }
            }
        }
    }

    /**
     * Register the restart receiver to listen for restart broadcasts
     */
    fun registerRestartReceiver() {
        if (!isRegistered) {
            try {
                val filter = IntentFilter(RESTART_ACTION)
                context.registerReceiver(restartReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                isRegistered = true
                Log.d(TAG, "Restart receiver registered")
            } catch (e: Exception) {
                Log.e(TAG, "Error registering restart receiver: ${e.message}", e)
            }
        }
    }

    /**
     * Unregister the restart receiver
     */
    fun unregisterRestartReceiver() {
        if (isRegistered && restartReceiver != null) {
            try {
                context.unregisterReceiver(restartReceiver)
                isRegistered = false
                Log.d(TAG, "Restart receiver unregistered")
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering restart receiver: ${e.message}", e)
            }
        }
    }

    /**
     * Schedule a service restart after a delay
     */
    fun scheduleServiceRestart() {
        try {
            val restartIntent = Intent(context, ServiceRestartReceiver::class.java).apply {
                action = RESTART_ACTION
            }

            val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.getBroadcast(
                    context,
                    0,
                    restartIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            } else {
                PendingIntent.getBroadcast(
                    context,
                    0,
                    restartIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT
                )
            }

            val triggerTime = System.currentTimeMillis() + RESTART_DELAY_MS

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager?.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } else {
                alarmManager?.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            }

            Log.d(TAG, "Service restart scheduled for ${RESTART_DELAY_MS}ms from now")
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling service restart: ${e.message}", e)
        }
    }

    /**
     * Cancel any pending service restart
     */
    fun cancelServiceRestart() {
        try {
            val restartIntent = Intent(context, ServiceRestartReceiver::class.java).apply {
                action = RESTART_ACTION
            }

            val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.getBroadcast(
                    context,
                    0,
                    restartIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            } else {
                PendingIntent.getBroadcast(
                    context,
                    0,
                    restartIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT
                )
            }

            alarmManager?.cancel(pendingIntent)
            Log.d(TAG, "Service restart cancelled")
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling service restart: ${e.message}", e)
        }
    }

    /**
     * Immediately restart the service
     */
    private fun restartService() {
        try {
            // Check if there are any blocked apps before starting service
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val blockedApps = prefs.getStringSet("blocked_apps", null)
            
            if (blockedApps != null && blockedApps.isNotEmpty()) {
                Log.d(TAG, "Found ${blockedApps.size} blocked apps, restarting service")
                
                val serviceIntent = Intent(context, AppLaunchInterceptor::class.java)
                
                // Use startForegroundService for Android 8.0+ to avoid crashes
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                
                Log.d(TAG, "AppLaunchInterceptor service restarted successfully")
            } else {
                Log.d(TAG, "No blocked apps found, skipping service restart")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error restarting service: ${e.message}", e)
        }
    }
}

/**
 * Standalone BroadcastReceiver for service restart
 */
class ServiceRestartReceiver : BroadcastReceiver() {
    private val TAG = "ServiceRestartReceiver"

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == "com.detach.app.RESTART_SERVICE") {
            Log.d(TAG, "ServiceRestartReceiver: Restarting AppLaunchInterceptor service")
            
            context?.let {
                try {
                    // Check if there are any blocked apps before starting service
                    val prefs = it.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val blockedApps = prefs.getStringSet("blocked_apps", null)
                    
                    if (blockedApps != null && blockedApps.isNotEmpty()) {
                        Log.d(TAG, "Found ${blockedApps.size} blocked apps, restarting service")
                        
                        val serviceIntent = Intent(it, AppLaunchInterceptor::class.java)
                        
                        // Use startForegroundService for Android 8.0+ to avoid crashes
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            it.startForegroundService(serviceIntent)
                        } else {
                            it.startService(serviceIntent)
                        }
                        
                        Log.d(TAG, "AppLaunchInterceptor service restarted successfully")
                    } else {
                        Log.d(TAG, "No blocked apps found, skipping service restart")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error restarting service: ${e.message}", e)
                }
            }
        }
    }
} 