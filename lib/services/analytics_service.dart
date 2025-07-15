import 'dart:developer';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:detach/firebase_options.dart';
class AnalyticsService extends GetxService {
  static AnalyticsService get to => Get.find();
  FirebaseAnalytics? _firebaseAnalytics;
  FirebaseAnalyticsObserver? _firebaseAnalyticsObserver;
  @override
  void onInit() {
    super.onInit();
    _initializeAnalytics();
  }
  Future<void> _initializeAnalytics() async {
    try {
      
      // Firebase is already initialized in main.dart, just get the analytics instance
      _firebaseAnalytics = FirebaseAnalytics.instance;
      
      _firebaseAnalyticsObserver = FirebaseAnalyticsObserver(
        analytics: _firebaseAnalytics!,
      );
      
      // Set default user properties
      await _setDefaultUserProperties();
      
    } catch (e) {
      
      
    }
  }
  Future<void> _setDefaultUserProperties() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      final connectivity = await Connectivity().checkConnectivity();
      // Set user properties
      await _firebaseAnalytics?.setUserProperty(
        name: 'app_version',
        value: packageInfo.version,
      );
      await _firebaseAnalytics?.setUserProperty(
        name: 'build_number',
        value: packageInfo.buildNumber,
      );
      await _firebaseAnalytics?.setUserProperty(
        name: 'connectivity_type',
        value: connectivity.toString(),
      );
      // Platform-specific device info
      if (GetPlatform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        await _firebaseAnalytics?.setUserProperty(
          name: 'device_model',
          value: androidInfo.model,
        );
        await _firebaseAnalytics?.setUserProperty(
          name: 'android_version',
          value: androidInfo.version.release,
        );
      } else if (GetPlatform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        await _firebaseAnalytics?.setUserProperty(
          name: 'device_model',
          value: iosInfo.model,
        );
        await _firebaseAnalytics?.setUserProperty(
          name: 'ios_version',
          value: iosInfo.systemVersion,
        );
      }
    } catch (e) {
      
    }
  }
  // Firebase Analytics Methods
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
       
      if (_firebaseAnalytics == null) {
        
        
        return;
      }
      // Check if Firebase is properly initialized
      
      
      await _firebaseAnalytics!.logEvent(name: name, parameters: parameters);
      if (kDebugMode) {
         
         
      }
    } catch (e) {
      
      
    }
  }
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _firebaseAnalytics?.setUserProperty(name: name, value: value);
      if (kDebugMode) {
        
      }
    } catch (e) {
      
    }
  }
  Future<void> setUserId(String userId) async {
    try {
      await _firebaseAnalytics?.setUserId(id: userId);
      if (kDebugMode) {
        
      }
    } catch (e) {
      
    }
  }
  // App-specific analytics methods
  Future<void> logAppLaunch() async {
    await logEvent(name: 'app_launch');
  }
  Future<void> logPermissionRequest(String permissionType) async {
    await logEvent(
      name: 'permission_requested',
      parameters: {'permission_type': permissionType},
    );
  }
  Future<void> logPermissionGranted(String permissionType) async {
    await logEvent(
      name: 'permission_granted',
      parameters: {'permission_type': permissionType},
    );
  }
  Future<void> logPermissionDenied(String permissionType) async {
    await logEvent(
      name: 'permission_denied',
      parameters: {'permission_type': permissionType},
    );
  }
  Future<void> logAppBlocked(String appName) async {
    await logEvent(name: 'app_blocked', parameters: {'app_name': appName});
  }
  Future<void> logAppUnblocked(String appName) async {
    await logEvent(name: 'app_unblocked', parameters: {'app_name': appName});
  }
  Future<void> logPauseSession(int durationMinutes) async {
    await logEvent(
      name: 'pause_session_started',
      parameters: {'duration_minutes': durationMinutes},
    );
  }
  Future<void> logPauseSessionCompleted(int actualDurationMinutes) async {
    await logEvent(
      name: 'pause_session_completed',
      parameters: {'actual_duration_minutes': actualDurationMinutes},
    );
  }
  Future<void> logPauseSessionInterrupted() async {
    await logEvent(name: 'pause_session_interrupted');
  }
  Future<void> logScreenView(String screenName) async {
    await logEvent(
      name: 'screen_view',
      parameters: {'screen_name': screenName},
    );
  }
  Future<void> logFeatureUsage(String featureName) async {
    await logEvent(
      name: 'feature_used',
      parameters: {'feature_name': featureName},
    );
  }
  Future<void> logError(String errorType, String errorMessage) async {
    await logEvent(
      name: 'app_error',
      parameters: {'error_type': errorType, 'error_message': errorMessage},
    );
  }
  // Getter for Firebase Analytics Observer (for GetX navigation tracking)
  FirebaseAnalyticsObserver? get firebaseAnalyticsObserver =>
      _firebaseAnalyticsObserver;
}
