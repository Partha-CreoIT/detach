package com.detach.app

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.IBinder
import android.util.Log
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.Timer
import java.util.TimerTask
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

class AppLaunchInterceptor : Service() {
    private val TAG = "AppLaunchInterceptor"
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var handler: Handler
    private var lastEventTime = 0L
    private val permanentlyBlockedApps = ConcurrentHashMap.newKeySet<String>()
    private var isMonitoringEnabled = AtomicBoolean(true)
    private val unblockedApps = ConcurrentHashMap<String, Long>()
    private val cooldownMillis = 5000L // 5 seconds
    private var lastForegroundApp: String? = null
    private val earlyClosedApps = ConcurrentHashMap<String, Long>()
    private var isServiceRunning = AtomicBoolean(false)

    // Session tracking for timer-based app usage
    private data class AppSession(
        val startTime: Long,
        val durationSeconds: Int,
        val timer: Timer? = null,
        var elapsedSeconds: Int = 0,
        var handlerRunnable: Runnable? = null,
        var lastLogTime: Long = 0L
    )

    private val appSessions = ConcurrentHashMap<String, AppSession>()
    private val timerHandler = Handler(Looper.getMainLooper())
    private val timerExecutor = Executors.newSingleThreadScheduledExecutor { r ->
        Thread(r, "TimerExecutor").apply {
            isDaemon = true
            priority = Thread.NORM_PRIORITY
        }
    }

    companion object {
        var currentlyPausedApp: String? = null
        const val APP_SESSION_PREFIX = "app_session_"
        const val APP_SESSION_DURATION_SUFFIX = "_duration"
    }

    private val resetBlockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            try {
                if (intent?.action == "com.example.detach.RESET_APP_BLOCK") {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null) {
                        permanentlyBlockedApps.remove(packageName)
                        // Add to unblocked apps with current timestamp
                        unblockedApps[packageName] = System.currentTimeMillis()
                    }
                } else if (intent?.action == "com.example.detach.PERMANENTLY_BLOCK_APP") {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null) {
                        permanentlyBlockedApps.add(packageName)
                    }
                } else if (intent?.action == "com.example.detach.RESET_PAUSE_FLAG") {
                    val packageName = intent.getStringExtra("package_name")
                    if (packageName != null && currentlyPausedApp == packageName) {
                        currentlyPausedApp = null
                    }
                } else if (intent?.action == "com.example.detach.START_APP_SESSION") {
                    val packageName = intent.getStringExtra("package_name")
                    val durationSeconds = intent.getIntExtra("duration_seconds", 0)
                    Log.d(TAG, "Received START_APP_SESSION broadcast: package=$packageName, duration=$durationSeconds")
                    if (packageName != null && durationSeconds > 0) {
                        // Start tracking this app session
                        startAppSession(packageName, durationSeconds)
                    } else {
                        Log.e(TAG, "Invalid START_APP_SESSION parameters: package=$packageName, duration=$durationSeconds")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in broadcast receiver: ${e.message}")
                e.printStackTrace()
            }
        }
    }

    private fun startAppSession(packageName: String, durationSeconds: Int) {
        try {
            Log.d(TAG, "=== startAppSession called for $packageName, duration: $durationSeconds seconds ===")
            
            // Check if timer already exists for this app
            val existingSession = appSessions[packageName]
            if (existingSession != null) {
                Log.d(TAG, "Timer already exists for $packageName, canceling existing timer")
                try {
                    existingSession.timer?.cancel()
                    existingSession.handlerRunnable?.let { handler.removeCallbacks(it) }
                } catch (e: Exception) {
                    Log.e(TAG, "Error canceling existing timer: ${e.message}")
                }
                appSessions.remove(packageName)
            }
            
            // TEMPORARILY UNBLOCK THE APP - Remove from blocked apps list
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
            Log.d(TAG, "Current blocked apps before unblocking: $blockedApps")
            
            if (blockedApps.contains(packageName)) {
                blockedApps.remove(packageName)
                prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                Log.d(TAG, "TEMPORARILY UNBLOCKED $packageName from blocked apps: $blockedApps")
            } else {
                Log.d(TAG, "$packageName was not in blocked apps list")
            }
            
            // Save session data in shared preferences for persistence across app restarts
            val startTime = System.currentTimeMillis()
            val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
            val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"

            Log.d(TAG, "Session keys: $sessionStartKey, $sessionDurationKey")
            Log.d(TAG, "Start time: $startTime")

            // Create Executor-based timer for this session (more reliable for background services)
            val runnable = object : Runnable {
                override fun run() {
                    try {
                        if (!isServiceRunning.get()) {
                            Log.d(TAG, "Service not running, stopping timer for $packageName")
                            return
                        }
                        
                        Log.d(TAG, "Timer task executing for $packageName")
                        val session = appSessions[packageName]
                        if (session != null) {
                            session.elapsedSeconds++
                            val remainingSeconds = durationSeconds - session.elapsedSeconds
                            
                            // Log progress every second
                            Log.d(TAG, "⏱️ App opened: ${session.elapsedSeconds}/$durationSeconds seconds")
                            
                            // If timer expires
                            if (session.elapsedSeconds >= durationSeconds) {
                                Log.d(TAG, "🛑 === TIMER EXPIRED for $packageName ===")
                                handleTimerExpired(packageName)
                            } else {
                                // Schedule next execution using executor
                                if (isServiceRunning.get()) {
                                    timerExecutor.schedule(this, 1, TimeUnit.SECONDS)
                                }
                            }
                        } else {
                            Log.w(TAG, "❌ Session not found for $packageName in timer task")
                            Log.w(TAG, "Available sessions: ${appSessions.keys}")
                            Log.w(TAG, "Total sessions count: ${appSessions.size}")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in timer task for $packageName: ${e.message}")
                        e.printStackTrace()
                    }
                }
            }
            
            // Start the executor timer immediately and then every second
            if (isServiceRunning.get()) {
                timerExecutor.schedule(runnable, 0, TimeUnit.SECONDS)
                Log.d(TAG, "⏰ EXECUTOR TIMER STARTED immediately for $packageName, duration: $durationSeconds seconds")
                Log.d(TAG, "Timer will expire at: ${System.currentTimeMillis() + (durationSeconds * 1000L)}")
                Log.d(TAG, "Timer should start logging: 'App opened: X/$durationSeconds seconds'")
            }

            // Save in memory with handler runnable
            appSessions[packageName] = AppSession(startTime, durationSeconds, null, 0, runnable)
            Log.d(TAG, "✅ SAVED SESSION in memory with timer for $packageName")
            Log.d(TAG, "Active sessions count: ${appSessions.size}")
            Log.d(TAG, "Active sessions: ${appSessions.keys}")
            Log.d(TAG, "Session details: startTime=$startTime, duration=$durationSeconds")

            // Save in shared preferences for persistence
            val editor = prefs.edit()
            editor.putString(sessionStartKey, startTime.toString())
            editor.putInt(sessionDurationKey, durationSeconds)
            val success = editor.commit() // Use commit() instead of apply() for immediate persistence

            Log.d(TAG, "Saved session to SharedPreferences, success: $success")
            
            // Verify the save worked
            val savedStartTime = prefs.getString(sessionStartKey, null)
            val savedDuration = prefs.getInt(sessionDurationKey, -1)
            Log.d(TAG, "Verification - saved startTime: $savedStartTime, saved duration: $savedDuration")
            
            Log.d(TAG, "=== startAppSession completed for $packageName ===")
        } catch (e: Exception) {
            Log.e(TAG, "Error in startAppSession for $packageName: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun handleTimerExpired(packageName: String) {
        try {
            Log.d(TAG, "=== handleTimerExpired called for $packageName ===")
            
            // Verify the session exists
            val session = appSessions[packageName]
            if (session == null) {
                Log.w(TAG, "No session found for $packageName in handleTimerExpired")
                return
            }
            
            Log.d(TAG, "Timer expired for $packageName, session duration: ${session.durationSeconds} seconds")
            
            // RE-BLOCK THE APP - Add back to blocked list
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
            
            if (!blockedApps.contains(packageName)) {
                blockedApps.add(packageName)
                Log.d(TAG, "TIMER EXPIRED: RE-BLOCKING $packageName - Added back to blocked apps: $blockedApps")
                prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
            } else {
                Log.d(TAG, "$packageName was already in blocked apps list")
            }

            // Clear the session data
            val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
            val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"
            prefs.edit()
                .remove(sessionStartKey)
                .remove(sessionDurationKey)
                .apply()
            
            // Remove from memory
            appSessions.remove(packageName)
            
            // Close the unblocked app
            closeApp(packageName)
            
            // Show pause screen again (timer expired normally)
            handler.post {
                try {
                    Log.d(TAG, "Timer expired: Showing pause screen for $packageName")
                    val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("blocked_app_package", packageName)
                        putExtra("show_lock", true)
                    }
                    startActivity(pauseIntent)
                    Log.d(TAG, "Pause screen launched after timer expiration")
                } catch (e: Exception) {
                    Log.e(TAG, "Error launching pause screen after timer expiration: ${e.message}")
                    e.printStackTrace()
                }
            }
            
            Log.d(TAG, "=== handleTimerExpired completed for $packageName ===")
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleTimerExpired: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun closeApp(packageName: String) {
        try {
            Log.d(TAG, "Closing app: $packageName")
            
            // Get the ActivityManager
            val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            
            // Kill background processes
            am.killBackgroundProcesses(packageName)
            
            // Try to force stop using shell command (requires root or system app)
            try {
                val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "am force-stop $packageName"))
                process.waitFor()
            } catch (e: Exception) {
                Log.d(TAG, "Could not force stop $packageName using shell command: ${e.message}")
            }
            
            Log.d(TAG, "App $packageName closed successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error closing app $packageName: ${e.message}")
            e.printStackTrace()
        }
    }

    // Debug method to check timer status
    private fun logTimerStatus() {
        try {
            Log.d(TAG, "=== Timer Status ===")
            Log.d(TAG, "Active sessions: ${appSessions.size}")
            for ((packageName, session) in appSessions) {
                val remainingTime = session.durationSeconds - session.elapsedSeconds
                Log.d(TAG, "Package: $packageName, Progress: ${session.elapsedSeconds}/${session.durationSeconds} seconds")
            }
            Log.d(TAG, "=== End Timer Status ===")
        } catch (e: Exception) {
            Log.e(TAG, "Error in logTimerStatus: ${e.message}")
        }
    }

    private fun restartTimerForSession(packageName: String, session: AppSession) {
        try {
            Log.d(TAG, "=== restartTimerForSession called for $packageName ===")
            
            // Cancel existing timer if any
            try {
                session.timer?.cancel()
                session.handlerRunnable?.let { handler.removeCallbacks(it) }
            } catch (e: Exception) {
                Log.e(TAG, "Error canceling existing timer: ${e.message}")
            }
            
            // Create new timer using Executor (more reliable for background services)
            val durationSeconds = session.durationSeconds
            val runnable = object : Runnable {
                override fun run() {
                    try {
                        if (!isServiceRunning.get()) {
                            Log.d(TAG, "Service not running, stopping restarted timer for $packageName")
                            return
                        }
                        
                        Log.d(TAG, "Executor timer executing for $packageName")
                        val currentSession = appSessions[packageName]
                        if (currentSession != null) {
                            currentSession.elapsedSeconds++
                            val currentRemaining = durationSeconds - currentSession.elapsedSeconds
                            
                            // Log progress every second
                            Log.d(TAG, "⏱️ App opened: ${currentSession.elapsedSeconds}/$durationSeconds seconds")
                            
                            // If timer expires
                            if (currentSession.elapsedSeconds >= durationSeconds) {
                                Log.d(TAG, "🛑 === TIMER EXPIRED for $packageName ===")
                                handleTimerExpired(packageName)
                            } else {
                                // Schedule next execution using executor
                                if (isServiceRunning.get()) {
                                    timerExecutor.schedule(this, 1, TimeUnit.SECONDS)
                                }
                            }
                        } else {
                            Log.w(TAG, "❌ Session not found for $packageName in executor timer")
                            Log.w(TAG, "Available sessions: ${appSessions.keys}")
                            Log.w(TAG, "Total sessions count: ${appSessions.size}")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in executor timer for $packageName: ${e.message}")
                        e.printStackTrace()
                    }
                }
            }
            
            // Start the executor timer immediately and then every second
            if (isServiceRunning.get()) {
                timerExecutor.schedule(runnable, 0, TimeUnit.SECONDS)
            }
            
            // Update session with new handler runnable (for compatibility)
            appSessions[packageName] = session.copy(handlerRunnable = runnable)
            
            Log.d(TAG, "✅ Executor timer restarted for $packageName")
        } catch (e: Exception) {
            Log.e(TAG, "Error restarting timer for $packageName: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun restoreSessionsFromSharedPreferences() {
        try {
            Log.d(TAG, "=== restoreSessionsFromSharedPreferences called ===")
            
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val allPrefs = prefs.all
            
            Log.d(TAG, "All SharedPreferences keys: ${allPrefs.keys}")
            
            // Find all session start keys
            val sessionStartKeys = allPrefs.keys.filter { it.startsWith(APP_SESSION_PREFIX) && it.endsWith("_start") }
            
            Log.d(TAG, "Found session start keys: $sessionStartKeys")
            
            for (startKey in sessionStartKeys) {
                try {
                    val packageName = startKey.removePrefix(APP_SESSION_PREFIX).removeSuffix("_start")
                    val durationKey = "${APP_SESSION_PREFIX}${packageName}_duration"
                    
                    Log.d(TAG, "Processing session for package: $packageName")
                    Log.d(TAG, "Looking for duration key: $durationKey")
                    
                    val startTimeStr = prefs.getString(startKey, null)
                    val durationSeconds = prefs.getInt(durationKey, 0)
                    
                    Log.d(TAG, "Found startTimeStr: $startTimeStr, durationSeconds: $durationSeconds")
                    
                    if (startTimeStr != null && durationSeconds > 0) {
                        val startTime = startTimeStr.toLongOrNull() ?: 0L
                        val currentTime = System.currentTimeMillis()
                        val elapsedSeconds = (currentTime - startTime) / 1000
                        
                        Log.d(TAG, "Session details for $packageName:")
                        Log.d(TAG, "  - Start time: $startTime")
                        Log.d(TAG, "  - Current time: $currentTime")
                        Log.d(TAG, "  - Duration seconds: $durationSeconds")
                        Log.d(TAG, "  - Elapsed seconds: $elapsedSeconds")
                        
                        // Check if timer has already expired
                        if (elapsedSeconds >= durationSeconds) {
                            Log.d(TAG, "🛑 Timer for $packageName has already expired, handling expiration")
                            handleTimerExpired(packageName)
                        } else {
                            Log.d(TAG, "⏰ Restoring active timer for $packageName, remaining: ${durationSeconds - elapsedSeconds} seconds")
                            
                            // Create new Handler-based timer for the remaining time
                            val remainingSeconds = durationSeconds - elapsedSeconds
                            
                            val runnable = object : Runnable {
                                override fun run() {
                                    try {
                                        if (!isServiceRunning.get()) {
                                            Log.d(TAG, "Service not running, stopping restored timer for $packageName")
                                            return
                                        }
                                        
                                        Log.d(TAG, "Restored timer task executing for $packageName")
                                        val session = appSessions[packageName]
                                        if (session != null) {
                                            session.elapsedSeconds++
                                            val currentRemaining = durationSeconds - session.elapsedSeconds
                                            
                                            // Log progress every second
                                            Log.d(TAG, "⏱️ App opened: ${session.elapsedSeconds}/$durationSeconds seconds")
                                            
                                            // If timer expires
                                            if (session.elapsedSeconds >= durationSeconds) {
                                                Log.d(TAG, "🛑 === TIMER EXPIRED for $packageName ===")
                                                handleTimerExpired(packageName)
                                            } else {
                                                // Schedule next execution using executor
                                                if (isServiceRunning.get()) {
                                                    timerExecutor.schedule(this, 1, TimeUnit.SECONDS)
                                                }
                                            }
                                        } else {
                                            Log.w(TAG, "❌ Session not found for $packageName in restored timer task")
                                            Log.w(TAG, "Available sessions: ${appSessions.keys}")
                                            Log.w(TAG, "Total sessions count: ${appSessions.size}")
                                        }
                                    } catch (e: Exception) {
                                        Log.e(TAG, "Error in restored timer task for $packageName: ${e.message}")
                                        e.printStackTrace()
                                    }
                                }
                            }
                            
                            // Restore session in memory FIRST before creating timer
                            appSessions[packageName] = AppSession(startTime, durationSeconds, null, elapsedSeconds.toInt(), runnable)
                            Log.d(TAG, "Session restored to memory for $packageName, appSessions size: ${appSessions.size}")
                            
                            // Start the executor timer immediately and then every second
                            if (isServiceRunning.get()) {
                                timerExecutor.schedule(runnable, 0, TimeUnit.SECONDS)
                                Log.d(TAG, "Executor timer started immediately for $packageName")
                            }
                            
                            Log.d(TAG, "✅ RESTORED SESSION for $packageName with remaining time: $remainingSeconds seconds")
                        }
                    } else {
                        Log.w(TAG, "Invalid session data for $packageName: startTimeStr=$startTimeStr, durationSeconds=$durationSeconds")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing session for $startKey: ${e.message}")
                    e.printStackTrace()
                }
            }
            
            Log.d(TAG, "=== restoreSessionsFromSharedPreferences completed ===")
            Log.d(TAG, "Restored ${appSessions.size} active sessions")
        } catch (e: Exception) {
            Log.e(TAG, "Error in restoreSessionsFromSharedPreferences: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun checkAndHandleEarlyAppClose(packageName: String) {
        try {
            Log.d(TAG, "=== checkAndHandleEarlyAppClose called for $packageName ===")
            
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val sessionStartKey = "${APP_SESSION_PREFIX}${packageName}_start"
            val sessionDurationKey = "${APP_SESSION_PREFIX}${packageName}_duration"
            
            Log.d(TAG, "Looking for session keys: $sessionStartKey, $sessionDurationKey")
            
            val startTimeStr = prefs.getString(sessionStartKey, null)
            val durationSeconds = prefs.getInt(sessionDurationKey, 0)
            
            Log.d(TAG, "Found startTimeStr: $startTimeStr, durationSeconds: $durationSeconds")
            
            if (startTimeStr != null && durationSeconds > 0) {
                val startTime = startTimeStr.toLongOrNull() ?: 0L
                val currentTime = System.currentTimeMillis()
                val elapsedSeconds = (currentTime - startTime) / 1000
                
                Log.d(TAG, "Session details:")
                Log.d(TAG, "  - Start time: $startTime")
                Log.d(TAG, "  - Current time: $currentTime")
                Log.d(TAG, "  - Duration seconds: $durationSeconds")
                Log.d(TAG, "  - Elapsed seconds: $elapsedSeconds")
                
                // If app was closed before timer finished
                if (elapsedSeconds < durationSeconds) {
                    Log.d(TAG, "*** APP $packageName CLOSED EARLY! SILENTLY RE-BLOCKING APP ***")

                    // EARLY CLOSE: Re-block the app silently
                    val blockedApps = prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet()
                        ?: mutableSetOf()
                    Log.d(TAG, "Current blocked apps before early close re-blocking: $blockedApps")
                    
                    if (!blockedApps.contains(packageName)) {
                        blockedApps.add(packageName)
                        Log.d(TAG, "EARLY CLOSE: SILENTLY RE-BLOCKING $packageName - Added to blocked apps: $blockedApps")
                        prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                        Log.d(TAG, "Saved blocked apps to SharedPreferences")
                    } else {
                        Log.d(TAG, "$packageName was already in blocked apps list")
                    }
                    
                    // Clear session data
                    prefs.edit()
                        .remove(sessionStartKey)
                        .remove(sessionDurationKey)
                        .apply()
                    Log.d(TAG, "Cleared session data for early closed app: $packageName")
                    
                    // Cancel the timer since app was closed early
                    val session = appSessions[packageName]
                    try {
                        session?.timer?.cancel()
                        session?.handlerRunnable?.let { handler.removeCallbacks(it) }
                        Log.d(TAG, "Cancelled timer and handler for early closed app: $packageName")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error canceling timer for early closed app: ${e.message}")
                    }
                    
                    // Remove from memory
                    appSessions.remove(packageName)
                    Log.d(TAG, "Removed session from memory for early closed app: $packageName")
                    
                    Log.d(TAG, "*** EARLY CLOSE HANDLING COMPLETED for $packageName ***")
                } else {
                    Log.d(TAG, "App $packageName was closed after timer finished, no re-blocking needed")
                    
                    // Clear session data since timer finished normally
                    prefs.edit()
                        .remove(sessionStartKey)
                        .remove(sessionDurationKey)
                        .apply()
                    Log.d(TAG, "Cleared session data for normally closed app: $packageName")
                    
                    // Remove from memory
                    appSessions.remove(packageName)
                    Log.d(TAG, "Removed session from memory for normally closed app: $packageName")
                }
            } else {
                Log.d(TAG, "No session data found for $packageName, skipping early close check")
            }
            
            Log.d(TAG, "=== checkAndHandleEarlyAppClose completed for $packageName ===")
        } catch (e: Exception) {
            Log.e(TAG, "Error in checkAndHandleEarlyAppClose for $packageName: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun onCreate() {
        try {
            super.onCreate()
            Log.d(TAG, "=== AppLaunchInterceptor onCreate ===")
            
            isServiceRunning.set(true)

            // Start as foreground service to prevent being killed
            startForegroundService()
            
            usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            handler = Handler(Looper.getMainLooper())
            
            // Register broadcast receiver
            val filter = IntentFilter().apply {
                addAction("com.example.detach.RESET_APP_BLOCK")
                addAction("com.example.detach.PERMANENTLY_BLOCK_APP")
                addAction("com.example.detach.RESET_PAUSE_FLAG")
                addAction("com.example.detach.START_APP_SESSION")
            }
            registerReceiver(resetBlockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            Log.d(TAG, "Broadcast receiver registered successfully")
            
            // RESTORE SESSIONS FROM SHAREDPREFERENCES
            restoreSessionsFromSharedPreferences()
            
            startMonitoring()
            Log.d(TAG, "=== AppLaunchInterceptor onCreate completed ===")
            
            // Log timer status after a delay
            handler.postDelayed({
                try {
                    logTimerStatus()
                } catch (e: Exception) {
                    Log.e(TAG, "Error in delayed logTimerStatus: ${e.message}")
                }
            }, 2000) // 2 seconds delay
            
            // Add periodic logging to track service health
            handler.postDelayed({
                try {
                    Log.d(TAG, "=== Service Health Check ===")
                    Log.d(TAG, "Service is running, active sessions: ${appSessions.size}")
                    Log.d(TAG, "Session packages: ${appSessions.keys}")
                    for ((packageName, session) in appSessions) {
                        val remaining = session.durationSeconds - session.elapsedSeconds
                        Log.d(TAG, "Session $packageName: ${session.elapsedSeconds}/${session.durationSeconds} seconds (${remaining} remaining)")
                        
                        // Check if timer is still active
                        if (session.handlerRunnable == null) {
                            Log.w(TAG, "Handler runnable is null for $packageName, restarting timer")
                            restartTimerForSession(packageName, session)
                        }
                        
                        // Force timer progress if it seems stuck
                        val currentTime = System.currentTimeMillis()
                        val expectedElapsed = (currentTime - session.startTime) / 1000
                        if (session.elapsedSeconds < expectedElapsed - 2) { // Allow 2 second tolerance
                            Log.w(TAG, "Timer seems stuck for $packageName, forcing progress")
                            session.elapsedSeconds = expectedElapsed.toInt()
                            Log.d(TAG, "⏱️ App opened: ${session.elapsedSeconds}/${session.durationSeconds} seconds (forced)")
                            
                            if (session.elapsedSeconds >= session.durationSeconds) {
                                Log.d(TAG, "🛑 === TIMER EXPIRED for $packageName ===")
                                handleTimerExpired(packageName)
                            }
                        }
                    }
                    Log.d(TAG, "=== End Service Health Check ===")
                } catch (e: Exception) {
                    Log.e(TAG, "Error in service health check: ${e.message}")
                    e.printStackTrace()
                }
            }, 5000) // 5 seconds delay for more frequent checks
        } catch (e: Exception) {
            Log.e(TAG, "Error in onCreate: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun startForegroundService() {
        try {
            // Create notification channel for Android 8.0+
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channelId = "detach_service_channel"
                val channelName = "Detach Service"
                val channel = android.app.NotificationChannel(
                    channelId,
                    channelName,
                    android.app.NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Keeps the app blocker service running"
                    setShowBadge(false)
                }
                
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                notificationManager.createNotificationChannel(channel)
                
                val notification = android.app.Notification.Builder(this, channelId)
                    .setContentTitle("Detach Active")
                    .setContentText("App blocker service is running")
                    .setSmallIcon(android.R.drawable.ic_lock_idle_charging)
                    .setOngoing(true)
                    .build()
                
                startForeground(1001, notification)
                Log.d(TAG, "Started as foreground service")
            } else {
                val notification = android.app.Notification.Builder(this)
                    .setContentTitle("Detach Active")
                    .setContentText("App blocker service is running")
                    .setSmallIcon(android.R.drawable.ic_lock_idle_charging)
                    .setOngoing(true)
                    .build()
                
                startForeground(1001, notification)
                Log.d(TAG, "Started as foreground service (legacy)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting foreground service: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun startMonitoring() {
        try {
            Log.d(TAG, "=== startMonitoring called ===")
            
            // Start monitoring in a separate thread to avoid blocking the main thread
            Thread {
                try {
                    while (isServiceRunning.get()) {
                        try {
                            processUsageEvents()
                            Thread.sleep(1000) // Check every second
                        } catch (e: Exception) {
                            Log.e(TAG, "Error in monitoring loop: ${e.message}")
                            Thread.sleep(2000) // Wait longer on error
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in monitoring thread: ${e.message}")
                    e.printStackTrace()
                }
            }.apply {
                name = "UsageMonitoringThread"
                isDaemon = true
                start()
            }
            
            Log.d(TAG, "=== startMonitoring completed ===")
        } catch (e: Exception) {
            Log.e(TAG, "Error in startMonitoring: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun processUsageEvents() {
        try {
            val currentTime = System.currentTimeMillis()
            val usageEvents = usageStatsManager.queryEvents(lastEventTime, currentTime)
            val event = UsageEvents.Event()
            
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                
                // Detect when an app comes to foreground
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    val packageName = event.packageName
                    if (packageName != null && packageName != "com.detach.app") {
                        Log.d(TAG, "App moved to foreground: $packageName")
                        Log.d(TAG, "Calling handleAppLaunch for foreground app: $packageName")
                        handleAppLaunch(packageName)
                        lastForegroundApp = packageName
                    }
                }
                // Detect when an allowed app leaves the foreground
                if (event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND) {
                    val packageName = event.packageName
                    if (packageName != null && packageName != "com.detach.app") {
                        Log.d(TAG, "App moved to background: $packageName")
                        Log.d(TAG, "Calling handleAppBackgrounded for background app: $packageName")
                        handleAppBackgrounded(packageName)
                    }
                }
            }
            lastEventTime = currentTime
        } catch (e: Exception) {
            Log.e(TAG, "Error in processUsageEvents: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun handleAppLaunch(packageName: String) {
        try {
            Log.d(TAG, "=== handleAppLaunch called for $packageName ===")

            // Check if this app has an active session (timer is running)
            val activeSession = appSessions[packageName]
            Log.d(TAG, "Active sessions: ${appSessions.keys}")
            Log.d(TAG, "Checking for active session for $packageName: ${activeSession != null}")
            if (activeSession != null) {
                Log.d(TAG, "✅ App $packageName has active session, allowing launch (timer running)")
                return
            }
            
            Log.d(TAG, "❌ App $packageName has NO active session, checking if blocked")

            // Check cooldown first
            val unblockTime = unblockedApps[packageName]
            if (unblockTime != null) {
                val currentTime = System.currentTimeMillis()
                if ((currentTime - unblockTime) < cooldownMillis) {
                    Log.d(TAG, "App $packageName is in cooldown period, skipping")
                    return
                } else {
                    Log.d(TAG, "App $packageName cooldown expired, removing from unblockedApps")
                    unblockedApps.remove(packageName)
                }
            }
            
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val blockedApps = prefs.getStringSet("blocked_apps", null)
            
            Log.d(TAG, "Blocked apps from SharedPreferences: $blockedApps")
            Log.d(TAG, "Checking if $packageName is in blocked apps: ${blockedApps?.contains(packageName)}")

            // Only show pause if not already showing for this app and not in cooldown
            if (blockedApps != null && blockedApps.contains(packageName)) {
                Log.d(TAG, "*** APP $packageName IS BLOCKED, SHOWING PAUSE SCREEN ***")
                
                // Reset currentlyPausedApp if it's been more than 10 seconds since last pause
                // This allows the pause screen to show again for the same app after a reasonable delay
                if (currentlyPausedApp == packageName) {
                    Log.d(TAG, "Resetting currentlyPausedApp from $currentlyPausedApp to null")
                    // For now, let's allow showing the pause screen again immediately
                    // This will help with the issue where the pause screen doesn't show
                    currentlyPausedApp = null
                }
                currentlyPausedApp = packageName
                Log.d(TAG, "Set currentlyPausedApp to $packageName")

                handler.post {
                    try {
                        Log.d(TAG, "Launching PauseActivity for $packageName")
                        val pauseIntent = Intent(this, PauseActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                            putExtra("blocked_app_package", packageName)
                            putExtra("show_lock", true)
                        }
                        startActivity(pauseIntent)
                        Log.d(TAG, "PauseActivity launched successfully")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error launching PauseActivity: ${e.message}")
                        e.printStackTrace()
                        // Reset the flag if there was an error launching the pause screen
                        currentlyPausedApp = null
                    }
                }
            } else {
                Log.d(TAG, "App $packageName is not blocked, allowing launch")
            }
            
            Log.d(TAG, "=== handleAppLaunch completed for $packageName ===")
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleAppLaunch for $packageName: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun handleAppBackgrounded(packageName: String) {
        try {
            Log.d(TAG, "=== handleAppBackgrounded called for $packageName ===")
            
            // Only check apps that have active sessions (timers running)
            val activeSession = appSessions[packageName]
            if (activeSession == null) {
                Log.d(TAG, "App $packageName has no active session, skipping background check")
                return
            }
            
            Log.d(TAG, "App $packageName has active session, checking for early close")
            
            // If the app was temporarily unblocked, re-block it immediately
            if (unblockedApps.containsKey(packageName)) {
                Log.d(TAG, "App $packageName was temporarily unblocked, re-blocking immediately")
                unblockedApps.remove(packageName)
                // Add back to blocked apps in SharedPreferences
                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                val blockedApps =
                    prefs.getStringSet("blocked_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                blockedApps.add(packageName)
                prefs.edit().putStringSet("blocked_apps", blockedApps).apply()
                Log.d(TAG, "Re-blocked $packageName in SharedPreferences")
            } else {
                Log.d(TAG, "App $packageName was not in unblockedApps list")
            }

            // Check if this app has an active session and was closed early
            Log.d(TAG, "Calling checkAndHandleEarlyAppClose for $packageName")
            checkAndHandleEarlyAppClose(packageName)
            
            Log.d(TAG, "=== handleAppBackgrounded completed for $packageName ===")
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleAppBackgrounded for $packageName: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            Log.d(TAG, "=== onStartCommand called ===")
            Log.d(TAG, "Current active sessions: ${appSessions.keys}")
            Log.d(TAG, "Total sessions count: ${appSessions.size}")
            
            if (intent != null) {
                val action = intent.action
                Log.d(TAG, "Received intent with action: $action")
                
                if (action == "com.example.detach.START_APP_SESSION") {
                    val packageName = intent.getStringExtra("package_name")
                    val durationSeconds = intent.getIntExtra("duration_seconds", 0)
                    Log.d(TAG, "Direct service call - START_APP_SESSION: package=$packageName, duration=$durationSeconds")
                    
                    if (packageName != null && durationSeconds > 0) {
                        // Check if we already have a session for this app
                        if (!appSessions.containsKey(packageName)) {
                            startAppSession(packageName, durationSeconds)
                        } else {
                            Log.d(TAG, "Session already exists for $packageName, skipping duplicate call")
                        }
                    }
                }
            }

            return START_STICKY
        } catch (e: Exception) {
            Log.e(TAG, "Error in onStartCommand: ${e.message}")
            e.printStackTrace()
            return START_STICKY
        }
    }
    
    override fun onDestroy() {
        try {
            super.onDestroy()
            Log.d(TAG, "=== AppLaunchInterceptor onDestroy ===")
            Log.d(TAG, "Active sessions before destroy: ${appSessions.keys}")
            Log.d(TAG, "Total sessions count: ${appSessions.size}")

            // Mark service as not running
            isServiceRunning.set(false)

            try {
                unregisterReceiver(resetBlockReceiver)
                Log.d(TAG, "Broadcast receiver unregistered")
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering broadcast receiver: ${e.message}")
                e.printStackTrace()
            }
            
            // Cancel all timers and handler runnables
            for ((packageName, session) in appSessions) {
                try {
                    session.timer?.cancel()
                    session.handlerRunnable?.let { handler.removeCallbacks(it) }
                    Log.d(TAG, "Cancelled timer and handler for $packageName")
                } catch (e: Exception) {
                    Log.e(TAG, "Error canceling timer for $packageName: ${e.message}")
                }
            }
            
            // Shutdown the executor
            try {
                timerExecutor.shutdown()
                if (!timerExecutor.awaitTermination(1, TimeUnit.SECONDS)) {
                    timerExecutor.shutdownNow()
                }
                Log.d(TAG, "Timer executor shutdown completed")
            } catch (e: Exception) {
                Log.e(TAG, "Error shutting down timer executor: ${e.message}")
                e.printStackTrace()
                timerExecutor.shutdownNow()
            }
            
            currentlyPausedApp = null
            Log.d(TAG, "=== AppLaunchInterceptor onDestroy completed ===")
        } catch (e: Exception) {
            Log.e(TAG, "Error in onDestroy: ${e.message}")
            e.printStackTrace()
        }
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
}