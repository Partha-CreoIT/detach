import 'dart:async';
import 'package:flutter/foundation.dart';
import 'platform_service.dart';
import 'permission_service.dart';

/// Service for managing app blocking functionality
class AppBlockerService extends ChangeNotifier {
  static final AppBlockerService _instance = AppBlockerService._internal();
  factory AppBlockerService() => _instance;
  AppBlockerService._internal();

  bool _isServiceRunning = false;
  bool _isServiceHealthy = false;
  List<String> _blockedApps = [];
  Timer? _healthCheckTimer;
  Timer? _serviceCheckTimer;

  // Getters
  bool get isServiceRunning => _isServiceRunning;
  bool get isServiceHealthy => _isServiceHealthy;
  List<String> get blockedApps => List.unmodifiable(_blockedApps);

  /// Initialize the app blocker service
  Future<void> initialize() async {
    // Start periodic health checks
    _startHealthChecks();

    // Load blocked apps
    await _loadBlockedApps();

    // Check service status
    await _checkServiceStatus();
  }

  /// Start the app blocking service
  Future<bool> startService() async {
    try {
      // Check permissions first
      final permissionService = PermissionService();
      final hasUsagePermission = await permissionService.hasUsagePermission();
      final hasOverlayPermission =
          await permissionService.hasOverlayPermission();
      final hasBatteryOptimization =
          await permissionService.hasBatteryOptimizationIgnored();

      final hasPermissions =
          hasUsagePermission && hasOverlayPermission && hasBatteryOptimization;
      if (!hasPermissions) {
        return false;
      }

      // Start the Android service with current blocked apps
      await PlatformService.startBlockerService(_blockedApps);

      // Wait a moment for service to start
      await Future.delayed(const Duration(seconds: 2));

      // Verify service is running
      final isRunning = await PlatformService.isBlockerServiceRunning();
      _isServiceRunning = isRunning;

      if (isRunning) {
        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Stop the app blocking service
  Future<void> stopService() async {
    try {
      // Note: We don't have a direct stop method, but the service will
      // stop itself when there are no blocked apps
      _blockedApps.clear();
      await _saveBlockedApps();

      _isServiceRunning = false;
      _isServiceHealthy = false;
      notifyListeners();
    } catch (e) {}
  }

  /// Add an app to the blocked list
  Future<void> blockApp(String packageName) async {
    if (!_blockedApps.contains(packageName)) {
      _blockedApps.add(packageName);
      await _saveBlockedApps();

      // Restart service to pick up new blocked app
      if (_isServiceRunning) {
        await startService();
      }

      notifyListeners();
    }
  }

  /// Remove an app from the blocked list
  Future<void> unblockApp(String packageName) async {
    if (_blockedApps.contains(packageName)) {
      _blockedApps.remove(packageName);
      await _saveBlockedApps();

      // Notify the service about the unblock
      await PlatformService.resetAppBlock(packageName);

      notifyListeners();
    }
  }

  /// Permanently block an app (user chose "I don't want to open")
  Future<void> permanentlyBlockApp(String packageName) async {
    await PlatformService.permanentlyBlockApp(packageName);
  }

  /// Launch an app with a timer
  Future<void> launchAppWithTimer(
      String packageName, int durationSeconds) async {
    try {
      // Temporarily unblock the app
      await unblockApp(packageName);

      // Launch with timer
      await PlatformService.launchAppWithTimer(packageName, durationSeconds);
    } catch (e) {
      rethrow;
    }
  }

  /// Force restart the service
  Future<void> forceRestartService() async {
    try {
      await PlatformService.forceRestartBlockerService();

      // Wait for restart
      await Future.delayed(const Duration(seconds: 3));

      // Check status
      await _checkServiceStatus();
    } catch (e) {}
  }

  /// Check service health and status
  Future<Map<String, dynamic>> checkServiceHealth() async {
    try {
      final healthInfo = await PlatformService.checkServiceHealth();

      _isServiceRunning = healthInfo['isRunning'] ?? false;
      _isServiceHealthy = healthInfo['hasPermissions'] ?? false;

      notifyListeners();

      return healthInfo;
    } catch (e) {
      return {
        'isRunning': false,
        'hasPermissions': false,
        'isPersistent': false,
        'error': e.toString(),
      };
    }
  }

  /// Test the pause screen for a specific app
  Future<void> testPauseScreen(String packageName) async {
    try {
      await PlatformService.testPauseScreen(packageName);
    } catch (e) {}
  }

  /// Test if a blocked app shows pause screen when opened
  Future<void> testBlockedAppOpening(String packageName) async {
    try {
      // First ensure the app is blocked
      await blockApp(packageName);

      // Wait a moment for the service to update
      await Future.delayed(const Duration(seconds: 1));

      // Try to launch the app - this should trigger the pause screen
      await PlatformService.launchApp(packageName);
    } catch (e) {}
  }

  /// Test the complete timer flow: block app, launch with timer, wait for expiry, try to open again
  Future<void> testCompleteTimerFlow(
      String packageName, int durationSeconds) async {
    try {
      // First ensure the app is blocked
      await blockApp(packageName);

      // Wait a moment for the service to update
      await Future.delayed(const Duration(seconds: 1));

      // Launch with timer
      await launchAppWithTimer(packageName, durationSeconds);

      // Wait for timer to expire (plus a small buffer)
      await Future.delayed(Duration(seconds: durationSeconds + 2));

      // Try to launch the app again - this should trigger the pause screen
      await PlatformService.launchApp(packageName);
    } catch (e) {}
  }

  /// Clear the pause flag for debugging purposes
  Future<void> clearPauseFlag([String? packageName]) async {
    try {
      await PlatformService.clearPauseFlag(packageName);
    } catch (e) {}
  }

  /// Start periodic health checks
  void _startHealthChecks() {
    // Check service status every 30 seconds
    _serviceCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkServiceStatus();
    });

    // Full health check every 5 minutes
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      checkServiceHealth();
    });
  }

  /// Stop periodic health checks
  void _stopHealthChecks() {
    _serviceCheckTimer?.cancel();
    _healthCheckTimer?.cancel();
  }

  /// Check if the service is running
  Future<void> _checkServiceStatus() async {
    try {
      final isRunning = await PlatformService.isBlockerServiceRunning();
      if (_isServiceRunning != isRunning) {
        _isServiceRunning = isRunning;
        notifyListeners();
      }
    } catch (e) {}
  }

  /// Load blocked apps from storage
  Future<void> _loadBlockedApps() async {
    try {
      _blockedApps = await PlatformService.getBlockedApps();
    } catch (e) {
      _blockedApps = [];
    }
  }

  /// Save blocked apps to storage
  Future<void> _saveBlockedApps() async {
    try {
      await PlatformService.startBlockerService(_blockedApps);
    } catch (e) {}
  }

  /// Dispose resources
  @override
  void dispose() {
    _stopHealthChecks();
    super.dispose();
  }
}
