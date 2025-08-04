import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/services/database_service.dart';
import 'package:detach/services/platform_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/installed_apps.dart';

class AppTrackingService extends GetxService with WidgetsBindingObserver {
  final DatabaseService _databaseService = DatabaseService();
  final RxString currentApp = ''.obs;
  final RxString currentAppName = ''.obs;
  final RxMap<String, DateTime> appStartTimes = <String, DateTime>{}.obs;
  final RxMap<String, DateTime> pauseStartTimes = <String, DateTime>{}.obs;

  Timer? _usageCheckTimer;
  bool _isInitialized = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _initializeTracking();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _usageCheckTimer?.cancel();
    super.onClose();
  }

  Future<void> _initializeTracking() async {
    if (_isInitialized) return;

    // Check if we should track (only in release mode)
    const bool isReleaseMode = bool.fromEnvironment('dart.vm.product');
    if (!isReleaseMode) {
      print('App tracking disabled in debug mode');
      return;
    }

    _isInitialized = true;

    // Start periodic usage checking
    _usageCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkCurrentAppUsage();
    });

    // Initial check
    _checkCurrentAppUsage();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _checkCurrentAppUsage();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      default:
        break;
    }
  }

  Future<void> _checkCurrentAppUsage() async {
    try {
      // Get current foreground app from platform service
      final currentPackage = await PlatformService.getCurrentForegroundApp();

      if (currentPackage != null && currentPackage.isNotEmpty) {
        // Skip tracking our own app
        if (currentPackage == 'com.detach.app') {
          _endCurrentAppSession();
          return;
        }

        // If app changed, end previous session and start new one
        if (currentApp.value != currentPackage) {
          _endCurrentAppSession();
          _startNewAppSession(currentPackage);
        }
      } else {
        _endCurrentAppSession();
      }
    } catch (e) {
      print('Error checking app usage: $e');
    }
  }

  Future<void> _startNewAppSession(String packageName) async {
    try {
      // Get app name
      final appName = await _getAppName(packageName);

      currentApp.value = packageName;
      currentAppName.value = appName;
      appStartTimes[packageName] = DateTime.now();

      // Check if this app is blocked/paused
      final isBlocked = await _isAppBlocked(packageName);
      if (isBlocked) {
        _startPauseSession(packageName, appName);
      } else {
        // Insert app usage record
        await _databaseService.insertAppUsage(
          packageName: packageName,
          appName: appName,
          startTime: DateTime.now(),
        );
      }
    } catch (e) {
      print('Error starting app session: $e');
    }
  }

  Future<void> _endCurrentAppSession() async {
    if (currentApp.value.isEmpty) return;

    try {
      final packageName = currentApp.value;
      final endTime = DateTime.now();

      // End app usage session
      await _databaseService.updateAppUsageEndTime(
        packageName: packageName,
        endTime: endTime,
      );

      // End pause session if exists
      if (pauseStartTimes.containsKey(packageName)) {
        await _databaseService.updatePauseSessionEndTime(
          packageName: packageName,
          pauseEndTime: endTime,
        );
        pauseStartTimes.remove(packageName);
      }

      // Clear current app
      currentApp.value = '';
      currentAppName.value = '';
      appStartTimes.remove(packageName);
    } catch (e) {
      print('Error ending app session: $e');
    }
  }

  Future<void> _startPauseSession(String packageName, String appName) async {
    try {
      pauseStartTimes[packageName] = DateTime.now();

      await _databaseService.insertPauseSession(
        packageName: packageName,
        appName: appName,
        pauseStartTime: DateTime.now(),
      );
    } catch (e) {
      print('Error starting pause session: $e');
    }
  }

  Future<void> _onAppPaused() async {
    // App is going to background, end current session
    _endCurrentAppSession();
  }

  Future<void> _onAppDetached() async {
    // App is being killed, end all sessions
    _endCurrentAppSession();
  }

  Future<String> _getAppName(String packageName) async {
    try {
      final apps = await InstalledApps.getInstalledApps(false, true);
      final app = apps.firstWhere(
        (app) => app.packageName == packageName,
      );
      return app.name;
    } catch (e) {
      return 'Unknown App';
    }
  }

  Future<bool> _isAppBlocked(String packageName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockedApps = prefs.getStringList("blocked_apps") ?? [];
      return blockedApps.contains(packageName);
    } catch (e) {
      return false;
    }
  }

  // Public method to manually track app pause (called from Android service)
  Future<void> trackAppPause(String packageName, String appName) async {
    try {
      await _databaseService.insertPauseSession(
        packageName: packageName,
        appName: appName,
        pauseStartTime: DateTime.now(),
      );
    } catch (e) {
      print('Error tracking app pause: $e');
    }
  }

  // Public method to manually track app resume (called from Android service)
  Future<void> trackAppResume(String packageName, String appName) async {
    try {
      await _databaseService.updatePauseSessionEndTime(
        packageName: packageName,
        pauseEndTime: DateTime.now(),
      );
    } catch (e) {
      print('Error tracking app resume: $e');
    }
  }

  // Public method to manually track app usage (called from Android service)
  Future<void> trackAppUsage(
      String packageName, String appName, DateTime startTime, DateTime? endTime) async {
    try {
      if (endTime != null) {
        await _databaseService.insertAppUsage(
          packageName: packageName,
          appName: appName,
          startTime: startTime,
          endTime: endTime,
        );
      } else {
        await _databaseService.insertAppUsage(
          packageName: packageName,
          appName: appName,
          startTime: startTime,
        );
      }
    } catch (e) {
      print('Error tracking app usage: $e');
    }
  }
}
