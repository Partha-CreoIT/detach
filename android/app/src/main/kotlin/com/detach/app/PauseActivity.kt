package com.detach.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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

    private val sessionEndReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "SESSION_END") {
                finish()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_pause)
        
        sharedPreferences = getSharedPreferences("DetachPrefs", Context.MODE_PRIVATE)
        
        // Register broadcast receiver
        val filter = IntentFilter("SESSION_END")
        registerReceiver(sessionEndReceiver, filter)
        
        // Get session data from intent
        sessionKey = intent.getStringExtra("sessionKey")
        startTime = intent.getLongExtra("startTime", 0)
        duration = intent.getLongExtra("duration", 0)
        
        if (sessionKey != null && startTime > 0 && duration > 0) {
            saveSessionData()
            startTimer()
        }
    }

    private fun saveSessionData() {
        sessionKey?.let { key ->
            val startTimeStr = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(startTime))
            val endTime = startTime + duration
            val endTimeStr = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(endTime))
            
            // Save to SharedPreferences as fallback
            sharedPreferences.edit().apply {
                putString("${key}_startTime", startTimeStr)
                putString("${key}_endTime", endTimeStr)
                putLong("${key}_startTimeMillis", startTime)
                putLong("${key}_endTimeMillis", endTime)
                putLong("${key}_duration", duration)
                apply()
            }
            
            // Try multiple methods to communicate with AppLaunchInterceptor
            sendSessionDataToService(key, startTimeStr, endTimeStr, startTime, endTime, duration)
        }
    }

    private fun sendSessionDataToService(sessionKey: String, startTimeStr: String, endTimeStr: String, startTime: Long, endTime: Long, duration: Long) {
        // Method 1: Local broadcast
        val broadcastIntent = Intent("SESSION_DATA_SAVE").apply {
            putExtra("sessionKey", sessionKey)
            putExtra("startTimeStr", startTimeStr)
            putExtra("endTimeStr", endTimeStr)
            putExtra("startTime", startTime)
            putExtra("endTime", endTime)
            putExtra("duration", duration)
        }
        sendBroadcast(broadcastIntent)
        
        // Method 2: Explicit service intent
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
        
        // Method 3: Direct method call (if service is running)
        try {
            val service = AppLaunchInterceptor()
            service.saveSessionData(sessionKey, startTimeStr, endTimeStr, startTime, endTime, duration)
        } catch (e: Exception) {
            // Service might not be running, which is expected
        }
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
                        // Timer finished
                        isTimerRunning = false
                        finish()
                    } else {
                        // Update timer display
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
        
        // Send timer update to Flutter
        methodChannel.invokeMethod("updateTimer", "$minutes:$seconds")
    }

    override fun onDestroy() {
        super.onDestroy()
        isTimerRunning = false
        timerRunnable?.let { handler.removeCallbacks(it) }
        
        // Unregister broadcast receiver
        try {
            unregisterReceiver(sessionEndReceiver)
        } catch (e: Exception) {
            // Receiver might not be registered
        }
        
        // Check if app was closed early
        checkEarlyClose()
    }

    private fun checkEarlyClose() {
        sessionKey?.let { key ->
            val currentTime = System.currentTimeMillis()
            val expectedEndTime = startTime + duration
            
            if (currentTime < expectedEndTime) {
                // App was closed early, save this information
                val earlyCloseTime = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(currentTime))
                sharedPreferences.edit().apply {
                    putString("${key}_earlyCloseTime", earlyCloseTime)
                    putLong("${key}_earlyCloseTimeMillis", currentTime)
                    putBoolean("${key}_closedEarly", true)
                    apply()
                }
                
                // Notify AppLaunchInterceptor about early close
                val earlyCloseIntent = Intent("EARLY_CLOSE_DETECTED").apply {
                    putExtra("sessionKey", key)
                    putExtra("earlyCloseTime", earlyCloseTime)
                    putExtra("earlyCloseTimeMillis", currentTime)
                    putExtra("expectedEndTime", expectedEndTime)
                }
                sendBroadcast(earlyCloseIntent)
                
                // Also try direct service call
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
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
                else -> result.notImplemented()
            }
        }
    }
}