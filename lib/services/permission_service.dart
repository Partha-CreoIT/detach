import 'package:flutter/services.dart';

class PermissionService {
  static const _channel = MethodChannel('com.detach.app/permissions');

  Future<bool> hasUsagePermission() async {
    try {
      return await _channel.invokeMethod<bool>('checkUsagePermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasAccessibilityPermission() async {
    try {
      return await _channel.invokeMethod<bool>(
            'checkAccessibilityPermission',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('checkOverlayPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasBatteryOptimizationIgnored() async {
    try {
      return await _channel.invokeMethod<bool>('checkBatteryOptimization') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageSettings');
    } catch (e) {
      // handle error
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      // handle error
    }
  }

  static Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } catch (e) {
      // handle error
    }
  }

  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatterySettings');
    } catch (e) {
      // handle error
    }
  }
}
