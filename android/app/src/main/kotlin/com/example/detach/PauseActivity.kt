package com.example.detach

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class PauseActivity : FlutterActivity() {

    private val TAG = "PauseActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val packageName = intent.getStringExtra("blocked_app_package")
        Log.d(TAG, "onCreate called with blocked package: $packageName")
        Log.d(TAG, "Intent extras: ${intent.extras}")
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
        Log.d(TAG, "onDestroy called")
    }
}