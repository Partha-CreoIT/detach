import 'dart:async';
import 'package:flutter/services.dart';

class PlatformService {
  static const MethodChannel _channel = MethodChannel(
    'com.detach.app/permissions',
  );

  /// Opens Usage Access settings screen
  static Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageSettings');
    } catch (e) {}
  }

  /// Opens Overlay permission settings screen
  static Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } catch (e) {}
  }

  /// Opens Battery optimization settings screen
  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatterySettings');
    } catch (e) {}
  }

  /// Starts the Android foreground service to monitor & block apps
  static Future<void> startBlockerService(List<String> blockedApps) async {
    try {
      await _channel.invokeMethod('startBlockerService', {
        'blockedApps': blockedApps,
      });
    } catch (e) {}
  }

  /// Start tracking an app session with a timer
  static Future<void> startAppSession(
      String packageName, int durationSeconds) async {
    try {
      await _channel.invokeMethod('startAppSession', {
        'packageName': packageName,
        'durationSeconds': durationSeconds,
      });
    } catch (e) {}
  }

  static Future<void> launchApp(String packageName) async {
    try {
      await _channel.invokeMethod('launchApp', {'packageName': packageName});
    } catch (e) {
      // Handle error
    }
  }

  /// Closes both the current app and the blocked app
  static Future<void> closeBothApps() async {
    try {
      await _channel.invokeMethod('closeBothApps');
    } catch (e) {}
  }

  /// Resets the permanent block for a specific app
  static Future<void> resetAppBlock(String packageName) async {
    try {
      await _channel.invokeMethod('resetAppBlock', {
        'packageName': packageName,
      });
    } catch (e) {}
  }

  /// Resets the pause flag for a specific app
  static Future<void> resetPauseFlag(String packageName) async {
    try {
      await _channel.invokeMethod('resetPauseFlag', {
        'packageName': packageName,
      });
    } catch (e) {}
  }

  /// Permanently blocks an app (user clicked "I don't want to open")
  static Future<void> permanentlyBlockApp(String packageName) async {
    try {
      await _channel.invokeMethod('permanentlyBlockApp', {
        'packageName': packageName,
      });
    } catch (e) {}
  }

  /// Check if the blocker service is running
  static Future<bool> isBlockerServiceRunning() async {
    try {
      final result = await _channel.invokeMethod('isBlockerServiceRunning');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get the current list of blocked apps
  static Future<List<String>> getBlockedApps() async {
    try {
      final result = await _channel.invokeMethod('getBlockedApps');
      return List<String>.from(result ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Closes the Flutter app completely (go to device home screen)
  static Future<void> closeApp() async {
    try {
      await _channel.invokeMethod('closeApp');
    } catch (e) {}
  }
}
