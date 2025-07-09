package com.example.detach

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import kotlinx.coroutines.*
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents

class AppBlockerService : Service() {
    private val CHANNEL_ID = "DetachServiceChannel"
    private val NOTIFICATION_ID = 1
    private var blockedApps: List<String> = emptyList()
    private var lastForegroundApp: String? = null
    private var job: Job? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        blockedApps = intent?.getStringArrayListExtra("blockedApps") ?: emptyList()
        Log.d("Detach", "Blocked apps: $blockedApps")
        startMonitoring()
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        job?.cancel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Detach App Blocker Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun buildNotification(): Notification {
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Detach is running")
            .setContentText("Monitoring apps in background")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .build()
    }

    private fun startMonitoring() {
        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        job = CoroutineScope(Dispatchers.Default).launch {
            while (isActive) {
                val time = System.currentTimeMillis()
                val usageEvents = usageStatsManager.queryEvents(time - 2000, time)
                val event = UsageEvents.Event()
                var foregroundApp: String? = null

                while (usageEvents.hasNextEvent()) {
                    usageEvents.getNextEvent(event)
                    if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                        foregroundApp = event.packageName
                    }
                }

                if (foregroundApp != null && foregroundApp != lastForegroundApp) {
                    lastForegroundApp = foregroundApp
                    Log.d("Detach", "Foreground app: $foregroundApp")

                    if (blockedApps.contains(foregroundApp)) {
                        Log.d("Detach", "Blocked app detected: $foregroundApp")
                        showBlockingScreen(foregroundApp)
                    }
                }

                delay(500)
            }
        }
    }

    private fun showBlockingScreen(packageName: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("show_lock", true)
            putExtra("locked_package", packageName)
        }
        startActivity(intent)
    }
}