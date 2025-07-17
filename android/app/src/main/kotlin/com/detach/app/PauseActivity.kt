package com.detach.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.*

class PauseActivity : FlutterActivity() {
    private val CHANNEL = "com.detach.app/pause"
    private lateinit var methodChannel: MethodChannel
    private lateinit var sharedPreferences: SharedPreferences
    private var sessionKey: String? = null
    private var startTime: Long = 0
    private var duration: Long = 0
    private var isTimerRunning = false
    private val handler = Handler(Looper.getMainLooper())
    private var timerRunnable: Runnable? = null

    private val TAG = "PauseActivity"

    private val sessionEndReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "SESSION_END") {
                finish()
            }
        }
    }

    private val minimizeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.detach.MINIMIZE_DETACH_APP") {
                Log.d(TAG, "Received minimize broadcast - minimizing Detach app")
                moveTaskToBack(true)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "=== PauseActivity.onCreate() called ===")
        Log.d(TAG, "Intent extras: ${intent.extras}")
        Log.d(TAG, "Intent action: ${intent.action}")

        // Disable animations for fresh start
        overridePendingTransition(0, 0)

        sharedPreferences = getSharedPreferences("DetachPrefs", Context.MODE_PRIVATE)

        val filter = IntentFilter("SESSION_END")
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            registerReceiver(sessionEndReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(sessionEndReceiver, filter)
        }

        // Register minimize receiver
        val minimizeFilter = IntentFilter("com.example.detach.MINIMIZE_DETACH_APP")
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            registerReceiver(minimizeReceiver, minimizeFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(minimizeReceiver, minimizeFilter)
        }

        sessionKey = intent.getStringExtra("sessionKey")
        startTime = intent.getLongExtra("startTime", 0)
        duration = intent.getLongExtra("duration", 0)

        // Check if this is a timer expiration case
        val timerExpired = intent.getBooleanExtra("timer_expired", false)
        if (timerExpired) {
            Log.d(TAG, "PauseActivity opened due to timer expiration - fresh start")
            // Don't start a new timer, just show the pause screen
        } else if (sessionKey != null && startTime > 0 && duration > 0) {
            saveSessionData()
            startTimer()
        }
    }

    private fun saveSessionData() {
        sessionKey?.let { key ->
            val startTimeStr = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(startTime))
            val endTime = startTime + duration
            val endTimeStr = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(endTime))

            sharedPreferences.edit().apply {
                putString("${key}_startTime", startTimeStr)
                putString("${key}_endTime", endTimeStr)
                putLong("${key}_startTimeMillis", startTime)
                putLong("${key}_endTimeMillis", endTime)
                putLong("${key}_duration", duration)
                apply()
            }

            sendSessionDataToService(key, startTimeStr, endTimeStr, startTime, endTime, duration)
        }
    }

    private fun sendSessionDataToService(sessionKey: String, startTimeStr: String, endTimeStr: String, startTime: Long, endTime: Long, duration: Long) {
        val broadcastIntent = Intent("SESSION_DATA_SAVE").apply {
            putExtra("sessionKey", sessionKey)
            putExtra("startTimeStr", startTimeStr)
            putExtra("endTimeStr", endTimeStr)
            putExtra("startTime", startTime)
            putExtra("endTime", endTime)
            putExtra("duration", duration)
        }
        sendBroadcast(broadcastIntent)

        val serviceIntent = Intent(this, AppLaunchInterceptor::class.java).apply {
            action = "SAVE_SESSION_DATA"
            putExtra("sessionKey", sessionKey)
            putExtra("startTimeStr", startTimeStr)
            putExtra("endTimeStr", endTimeStr)
            putExtra("startTime", startTime)
            putExtra("endTime", endTime)
            putExtra("duration", duration)
        }
        startService(serviceIntent)
    }

    private fun startTimer() {
        isTimerRunning = true
        timerRunnable = object : Runnable {
            override fun run() {
                if (isTimerRunning) {
                    val currentTime = System.currentTimeMillis()
                    val elapsed = currentTime - startTime
                    val remaining = duration - elapsed

                    if (remaining <= 0) {
                        isTimerRunning = false
                        finish()
                    } else {
                        updateTimerDisplay(remaining)
                        handler.postDelayed(this, 1000)
                    }
                }
            }
        }
        handler.post(timerRunnable!!)
    }

    private fun updateTimerDisplay(remainingMillis: Long) {
        val minutes = remainingMillis / 60000
        val seconds = (remainingMillis % 60000) / 1000
        methodChannel.invokeMethod("updateTimer", "$minutes:$seconds")
    }

    override fun onDestroy() {
        super.onDestroy()
        isTimerRunning = false
        timerRunnable?.let { handler.removeCallbacks(it) }

        try {
            unregisterReceiver(sessionEndReceiver)
        } catch (_: Exception) {}

        try {
            unregisterReceiver(minimizeReceiver)
        } catch (_: Exception) {}

        checkEarlyClose()
    }

    override fun finish() {
        super.finish()
        // Disable exit animations
        overridePendingTransition(0, 0)
    }

    private fun checkEarlyClose() {
        sessionKey?.let { key ->
            val currentTime = System.currentTimeMillis()
            val expectedEndTime = startTime + duration

            if (currentTime < expectedEndTime) {
                val earlyCloseTime = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(currentTime))
                sharedPreferences.edit().apply {
                    putString("${key}_earlyCloseTime", earlyCloseTime)
                    putLong("${key}_earlyCloseTimeMillis", currentTime)
                    putBoolean("${key}_closedEarly", true)
                    apply()
                }

                val earlyCloseIntent = Intent("EARLY_CLOSE_DETECTED").apply {
                    putExtra("sessionKey", key)
                    putExtra("earlyCloseTime", earlyCloseTime)
                    putExtra("earlyCloseTimeMillis", currentTime)
                    putExtra("expectedEndTime", expectedEndTime)
                }
                sendBroadcast(earlyCloseIntent)

                val serviceIntent = Intent(this, AppLaunchInterceptor::class.java).apply {
                    action = "EARLY_CLOSE_DETECTED"
                    putExtra("sessionKey", key)
                    putExtra("earlyCloseTime", earlyCloseTime)
                    putExtra("earlyCloseTimeMillis", currentTime)
                    putExtra("expectedEndTime", expectedEndTime)
                }
                startService(serviceIntent)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.e(TAG, "=== configureFlutterEngine called ===")
        Log.e(TAG, "Intent extras: ${intent.extras}")
        Log.e(TAG, "Intent action: ${intent.action}")

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Get intent data
        val packageName = intent.getStringExtra("blocked_app_package")
        val timerExpired = intent.getBooleanExtra("timer_expired", false)
        val timerState = intent.getStringExtra("timer_state")
        
        Log.e(TAG, "Package name: $packageName")
        Log.e(TAG, "Timer expired: $timerExpired")
        Log.e(TAG, "Timer state: $timerState")
        
        // Send initialization data to Flutter
        if (packageName != null) {
            Log.e(TAG, "Sending initialization data to Flutter...")
            handler.postDelayed({
                try {
                    Log.e(TAG, "Attempting to send initialization data...")
                    methodChannel.invokeMethod("initializePause", mapOf(
                        "packageName" to packageName,
                        "timerExpired" to timerExpired,
                        "timerState" to timerState
                    ))
                    Log.e(TAG, "Initialization data sent to Flutter successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending initialization data: ${e.message}", e)
                }
            }, 500) // 0.5 second delay
        }
        
        // Check if this is a timer expiration case and notify Flutter
        if (timerExpired) {
            Log.e(TAG, "Timer expired detected, notifying Flutter via method channel")
            // Use a small delay to ensure Flutter is ready
            handler.postDelayed({
                try {
                    Log.e(TAG, "Attempting to send timer expired notification...")
                    methodChannel.invokeMethod("timerExpired", mapOf(
                        "packageName" to packageName,
                        "timerState" to timerState
                    ))
                    Log.e(TAG, "Timer expired notification sent to Flutter successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending timer expired notification: ${e.message}", e)
                }
            }, 1000) // 1 second delay
        } else {
            Log.e(TAG, "Not a timer expiration case")
        }
        
        // Test method channel communication
        handler.postDelayed({
            try {
                Log.e(TAG, "Testing method channel communication...")
                methodChannel.invokeMethod("test", mapOf("message" to "Hello from Android"))
                Log.e(TAG, "Test method channel message sent")
            } catch (e: Exception) {
                Log.e(TAG, "Error sending test method channel message: ${e.message}", e)
            }
        }, 2000) // 2 second delay
        
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSessionInfo" -> {
                    val sessionInfo = mapOf(
                        "sessionKey" to sessionKey,
                        "startTime" to startTime,
                        "duration" to duration,
                        "remaining" to (if (isTimerRunning) (startTime + duration - System.currentTimeMillis()) else 0)
                    )
                    result.success(sessionInfo)
                }

                "stopTimer" -> {
                    isTimerRunning = false
                    timerRunnable?.let { handler.removeCallbacks(it) }
                    result.success(null)
                }

                "goToHomeAndFinish" -> {
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(homeIntent)
                    finishAndRemoveTask()
                    result.success(null)
                }

                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    Log.d(TAG, "Attempting to launch app: $packageName")

                    if (packageName != null) {
                        try {
                            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                            if (launchIntent != null) {
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)

                                startActivity(launchIntent)
                                Log.d(TAG, "Successfully launched app: $packageName")
                                result.success(true)
                            } else {
                                Log.e(TAG, "Launch intent is null for package: $packageName")
                                result.error("NO_LAUNCH_INTENT", "Cannot launch app: no launch intent", null)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error launching app $packageName: ${e.message}", e)
                            result.error("LAUNCH_ERROR", "Error launching app: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARG", "Package name is null.", null)
                    }
                }

                "launchAppWithTimer" -> {
                    val packageName = call.argument<String>("packageName")
                    val durationSeconds = call.argument<Int>("durationSeconds")
                    
                    if (packageName != null && durationSeconds != null) {
                        Log.d(TAG, "=== PauseActivity: launchAppWithTimer called ===")
                        Log.d(TAG, "Package: $packageName, Duration: $durationSeconds")
                        
                        // Ensure the AppLaunchInterceptor service is running
                        val serviceIntent = Intent(this, AppLaunchInterceptor::class.java)
                        startService(serviceIntent)
                        Log.d(TAG, "AppLaunchInterceptor service started")
                        
                        // Send to AppLaunchInterceptor to handle timer and launch
                        val launchIntent = Intent(this, AppLaunchInterceptor::class.java).apply {
                            action = "com.example.detach.LAUNCH_APP_WITH_TIMER"
                            putExtra("package_name", packageName)  // Changed from "packageName"
                            putExtra("duration_seconds", durationSeconds)  // Changed from "durationSeconds"
                        }
                        startService(launchIntent)
                        Log.d(TAG, "Launch intent sent to AppLaunchInterceptor with extras: package_name=$packageName, duration_seconds=$durationSeconds")
                        
                        result.success(true)
                    } else {
                        Log.e(TAG, "Invalid parameters: packageName=$packageName, durationSeconds=$durationSeconds")
                        result.error("INVALID_ARG", "Package name or duration is null", null)
                    }
                }
                
                "pauseScreenClosed" -> {
                    val packageName = call.argument<String>("package_name")
                    if (packageName != null) {
                        Log.d(TAG, "=== PauseActivity: pauseScreenClosed called ===")
                        Log.d(TAG, "Package: $packageName")
                        
                        // Send broadcast to AppLaunchInterceptor
                        val broadcastIntent = Intent("com.example.detach.PAUSE_SCREEN_CLOSED").apply {
                            putExtra("package_name", packageName)
                        }
                        sendBroadcast(broadcastIntent)
                        Log.d(TAG, "Sent PAUSE_SCREEN_CLOSED broadcast for $packageName")
                        
                        result.success(true)
                    } else {
                        Log.e(TAG, "Package name is null in pauseScreenClosed")
                        result.error("INVALID_ARG", "Package name is null", null)
                    }
                }

                "minimizeAppToBackground" -> {
                    Log.d(TAG, "=== PauseActivity: minimizeAppToBackground called ===")
                    try {
                        // Minimize the app to background
                        moveTaskToBack(true)
                        Log.d(TAG, "App minimized to background successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error minimizing app to background: ${e.message}", e)
                        result.error("MINIMIZE_ERROR", "Error minimizing app: ${e.message}", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun getInitialRoute(): String {
        val packageName = intent.getStringExtra("blocked_app_package")
        val timerExpired = intent.getBooleanExtra("timer_expired", false)
        val timerState = intent.getStringExtra("timer_state")
        
        Log.e(TAG, "=== getInitialRoute called ===")
        Log.e(TAG, "Package name from intent: $packageName")
        Log.e(TAG, "Timer expired: $timerExpired")
        Log.e(TAG, "Timer state: $timerState")
        Log.e(TAG, "All intent extras: ${intent.extras}")
        
        val route = if (packageName != null) {
            if (timerExpired) {
                "/pause?package=$packageName&timer_expired=true&timer_state=$timerState"
            } else {
                "/pause?package=$packageName"
            }
        } else {
            "/pause"
        }
        
        Log.e(TAG, "Returning route: $route")
        Log.e(TAG, "=== getInitialRoute completed ===")
        return route
    }
}
