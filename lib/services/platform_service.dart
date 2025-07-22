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

  /// Launch an app with a timer that runs on Android
  static Future<void> launchAppWithTimer(
      String packageName, int durationSeconds) async {
    try {
      await _channel.invokeMethod('launchAppWithTimer', {
        'packageName': packageName,
        'durationSeconds': durationSeconds,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Launch an app with a timer using the pause channel (when app opens directly to PauseActivity)
  static Future<void> launchAppWithTimerViaPause(
      String packageName, int durationSeconds) async {
    try {
      await const MethodChannel('com.detach.app/pause')
          .invokeMethod('launchAppWithTimer', {
        'packageName': packageName,
        'durationSeconds': durationSeconds,
      });
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> launchApp(String packageName) async {
    try {
      await _channel.invokeMethod('launchApp', {'packageName': packageName});
    } catch (e) {
      rethrow; // Re-throw to let calling code handle it
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

  /// Force restart the blocker service
  static Future<void> forceRestartBlockerService() async {
    try {
      await _channel.invokeMethod('forceRestartBlockerService');
    } catch (e) {
      // Handle error silently
    }
  }

  /// Check if the service has proper permissions and is persistent
  static Future<Map<String, dynamic>> checkServiceHealth() async {
    try {
      final result = await _channel.invokeMethod('checkServiceHealth');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {
        'isRunning': false,
        'hasPermissions': false,
        'isPersistent': false,
        'error': e.toString(),
      };
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

  /// Notify the native side that an app was blocked
  static Future<void> notifyAppBlocked(String packageName) async {
    try {
      await _channel.invokeMethod('notifyAppBlocked', {
        'packageName': packageName,
      });
    } catch (e) {}
  }

  /// Notify the native side that the Flutter app is being killed
  static Future<void> notifyAppKilled() async {
    try {
      await _channel.invokeMethod('notifyAppKilled');
    } catch (e) {}
  }

  /// Test the pause screen launch
  static Future<void> testPauseScreen(String packageName) async {
    try {
      await _channel.invokeMethod('testPauseScreen', {
        'packageName': packageName,
      });
    } catch (e) {
      // Handle error silently
    }
  }

  /// Clear the pause flag for debugging purposes
  static Future<void> clearPauseFlag([String? packageName]) async {
    try {
      await _channel.invokeMethod('clearPauseFlag', {
        'packageName': packageName,
      });
    } catch (e) {
      // Handle error silently
    }
  }
}
