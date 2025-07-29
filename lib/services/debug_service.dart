import 'package:flutter/services.dart';

class DebugService {
  static const MethodChannel _channel = MethodChannel('com.detach.app/permissions');

  /// Force show pause screen for debugging
  static Future<bool> forceShowPauseScreen(String packageName) async {
    try {
      final bool result = await _channel.invokeMethod('forceShowPauseScreen', {
        'packageName': packageName,
      });
      return result;
    } on PlatformException catch (e) {
      print('Error force showing pause screen: ${e.message}');
      return false;
    }
  }

  /// Reset pause flag for debugging
  static Future<bool> resetPauseFlag([String? packageName]) async {
    try {
      final bool result = await _channel.invokeMethod('resetPauseFlag', {
        'packageName': packageName,
      });
      return result;
    } on PlatformException catch (e) {
      print('Error resetting pause flag: ${e.message}');
      return false;
    }
  }

  /// Test overlay mode
  static Future<bool> testOverlayMode(String packageName) async {
    try {
      final bool result = await _channel.invokeMethod('testOverlayMode', {
        'packageName': packageName,
      });
      return result;
    } on PlatformException catch (e) {
      print('Error testing overlay mode: ${e.message}');
      return false;
    }
  }

  /// Get common test apps
  static List<String> getTestApps() {
    return [
      'dev.firebase.appdistribution', // Your test app
      'com.instagram.android', // Instagram
      'com.facebook.katana', // Facebook
      'com.whatsapp', // WhatsApp
      'com.google.android.youtube', // YouTube
    ];
  }
}
