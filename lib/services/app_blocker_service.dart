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
    debugPrint('AppBlockerService: Initializing...');

    // Start periodic health checks
    _startHealthChecks();

    // Load blocked apps
    await _loadBlockedApps();

    // Check service status
    await _checkServiceStatus();

    debugPrint('AppBlockerService: Initialized');
  }

  /// Start the app blocking service
  Future<bool> startService() async {
    try {
      debugPrint('AppBlockerService: Starting service...');

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
        debugPrint(
            'AppBlockerService: Missing permissions, cannot start service');
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
        debugPrint('AppBlockerService: Service started successfully');
        notifyListeners();
        return true;
      } else {
        debugPrint('AppBlockerService: Failed to start service');
        return false;
      }
    } catch (e) {
      debugPrint('AppBlockerService: Error starting service: $e');
      return false;
    }
  }

  /// Stop the app blocking service
  Future<void> stopService() async {
    try {
      debugPrint('AppBlockerService: Stopping service...');

      // Note: We don't have a direct stop method, but the service will
      // stop itself when there are no blocked apps
      _blockedApps.clear();
      await _saveBlockedApps();

      _isServiceRunning = false;
      _isServiceHealthy = false;
      notifyListeners();

      debugPrint('AppBlockerService: Service stopped');
    } catch (e) {
      debugPrint('AppBlockerService: Error stopping service: $e');
    }
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

      debugPrint('AppBlockerService: Blocked app: $packageName');
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

      debugPrint('AppBlockerService: Unblocked app: $packageName');
      notifyListeners();
    }
  }

  /// Permanently block an app (user chose "I don't want to open")
  Future<void> permanentlyBlockApp(String packageName) async {
    await PlatformService.permanentlyBlockApp(packageName);
    debugPrint('AppBlockerService: Permanently blocked app: $packageName');
  }

  /// Launch an app with a timer
  Future<void> launchAppWithTimer(
      String packageName, int durationSeconds) async {
    try {
      debugPrint(
          'AppBlockerService: Launching $packageName with ${durationSeconds}s timer');

      // Temporarily unblock the app
      await unblockApp(packageName);

      // Launch with timer
      await PlatformService.launchAppWithTimer(packageName, durationSeconds);

      debugPrint('AppBlockerService: App launched with timer successfully');
    } catch (e) {
      debugPrint('AppBlockerService: Error launching app with timer: $e');
      rethrow;
    }
  }

  /// Force restart the service
  Future<void> forceRestartService() async {
    try {
      debugPrint('AppBlockerService: Force restarting service...');
      await PlatformService.forceRestartBlockerService();

      // Wait for restart
      await Future.delayed(const Duration(seconds: 3));

      // Check status
      await _checkServiceStatus();

      debugPrint('AppBlockerService: Service force restarted');
    } catch (e) {
      debugPrint('AppBlockerService: Error force restarting service: $e');
    }
  }

  /// Check service health and status
  Future<Map<String, dynamic>> checkServiceHealth() async {
    try {
      final healthInfo = await PlatformService.checkServiceHealth();

      _isServiceRunning = healthInfo['isRunning'] ?? false;
      _isServiceHealthy = healthInfo['hasPermissions'] ?? false;

      debugPrint('AppBlockerService: Health check completed: $healthInfo');
      notifyListeners();

      return healthInfo;
    } catch (e) {
      debugPrint('AppBlockerService: Error checking service health: $e');
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
      debugPrint('AppBlockerService: Testing pause screen for $packageName');
      await PlatformService.testPauseScreen(packageName);
    } catch (e) {
      debugPrint('AppBlockerService: Error testing pause screen: $e');
    }
  }

  /// Test if a blocked app shows pause screen when opened
  Future<void> testBlockedAppOpening(String packageName) async {
    try {
      debugPrint(
          'AppBlockerService: Testing blocked app opening for $packageName');

      // First ensure the app is blocked
      await blockApp(packageName);

      // Wait a moment for the service to update
      await Future.delayed(const Duration(seconds: 1));

      // Try to launch the app - this should trigger the pause screen
      await PlatformService.launchApp(packageName);

      debugPrint(
          'AppBlockerService: Test completed - pause screen should appear');
    } catch (e) {
      debugPrint('AppBlockerService: Error testing blocked app opening: $e');
    }
  }

  /// Test the complete timer flow: block app, launch with timer, wait for expiry, try to open again
  Future<void> testCompleteTimerFlow(
      String packageName, int durationSeconds) async {
    try {
      debugPrint(
          'AppBlockerService: Testing complete timer flow for $packageName');

      // First ensure the app is blocked
      await blockApp(packageName);

      // Wait a moment for the service to update
      await Future.delayed(const Duration(seconds: 1));

      // Launch with timer
      await launchAppWithTimer(packageName, durationSeconds);

      debugPrint('AppBlockerService: Timer started, waiting for expiry...');

      // Wait for timer to expire (plus a small buffer)
      await Future.delayed(Duration(seconds: durationSeconds + 2));

      // Try to launch the app again - this should trigger the pause screen
      await PlatformService.launchApp(packageName);

      debugPrint(
          'AppBlockerService: Complete timer flow test finished - pause screen should appear');
    } catch (e) {
      debugPrint('AppBlockerService: Error testing complete timer flow: $e');
    }
  }

  /// Clear the pause flag for debugging purposes
  Future<void> clearPauseFlag([String? packageName]) async {
    try {
      debugPrint(
          'AppBlockerService: Clearing pause flag for ${packageName ?? "all apps"}');
      await PlatformService.clearPauseFlag(packageName);
      debugPrint('AppBlockerService: Pause flag cleared successfully');
    } catch (e) {
      debugPrint('AppBlockerService: Error clearing pause flag: $e');
    }
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
    } catch (e) {
      debugPrint('AppBlockerService: Error checking service status: $e');
    }
  }

  /// Load blocked apps from storage
  Future<void> _loadBlockedApps() async {
    try {
      _blockedApps = await PlatformService.getBlockedApps();
      debugPrint(
          'AppBlockerService: Loaded ${_blockedApps.length} blocked apps');
    } catch (e) {
      debugPrint('AppBlockerService: Error loading blocked apps: $e');
      _blockedApps = [];
    }
  }

  /// Save blocked apps to storage
  Future<void> _saveBlockedApps() async {
    try {
      await PlatformService.startBlockerService(_blockedApps);
      debugPrint(
          'AppBlockerService: Saved ${_blockedApps.length} blocked apps');
    } catch (e) {
      debugPrint('AppBlockerService: Error saving blocked apps: $e');
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _stopHealthChecks();
    super.dispose();
  }
}
