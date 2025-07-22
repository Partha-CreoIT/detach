import 'dart:async';
import 'package:get/get.dart';
import 'package:detach/services/platform_service.dart';
import 'package:detach/services/app_count_service.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:detach/app/routes/app_routes.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PauseController extends GetxController with GetTickerProviderStateMixin {
  late AnimationController waterController;
  late Animation<double> waterAnimation;

  // Timer/slider logic for PauseView
  final RxBool showTimer = false.obs;
  final int maxMinutes = 30;
  final RxInt selectedMinutes = 5.obs;
  late AnimationController progressController;
  late Animation<double> progressAnim;
  String appNameStr = "Google Docs";

  String get displayAppName =>
      appName.value.isNotEmpty ? appName.value : appNameStr;

  // Check if an app was closed early and handle accordingly
  Future<void> checkEarlyClose(String packageName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionStartKey = 'app_session_${packageName}_start';
      final sessionDurationKey = 'app_session_${packageName}_duration';

      // Check if we have a saved session
      if (prefs.containsKey(sessionStartKey)) {
        final startTimeStr = prefs.getString(sessionStartKey);
        final totalDuration = prefs.getInt(sessionDurationKey) ?? 0;

        if (startTimeStr != null) {
          final startTimeMillis = int.tryParse(startTimeStr) ?? 0;
          final startTime =
              DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
          final now = DateTime.now();
          final elapsedSeconds = now.difference(startTime).inSeconds;

          // If the app was closed before the timer finished
          if (elapsedSeconds < totalDuration) {
            // Add the app back to blocked list
            final blockedApps =
                prefs.getStringList("blocked_apps")?.toList() ?? [];

            if (!blockedApps.contains(packageName)) {
              blockedApps.add(packageName);
              await prefs.setStringList("blocked_apps", blockedApps);

              // Update the blocker service with new list
              try {
                await PlatformService.startBlockerService(blockedApps);
              } catch (e) {
                // Handle error silently
              }
            }
          }

          // Clear the session data
          await prefs.remove(sessionStartKey);
          await prefs.remove(sessionDurationKey);
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void startCountdown() async {
    try {
      if (lockedPackageName == null) {
        return;
      }

      // Reset the pause flag so the pause screen can show again for this app
      try {
        await PlatformService.resetPauseFlag(lockedPackageName!);
      } catch (e) {
        // Handle error silently
      }

      // Remove the app from blocked list temporarily
      final prefs = await SharedPreferences.getInstance();
      final blockedApps = prefs.getStringList("blocked_apps")?.toList() ?? [];

      blockedApps.remove(lockedPackageName);
      await prefs.setStringList("blocked_apps", blockedApps);

      // Reset the app block to prevent immediate re-blocking
      try {
        await PlatformService.resetAppBlock(lockedPackageName!);
      } catch (e) {
        // Handle error silently
      }

      // Update the blocker service with new list
      try {
        await PlatformService.startBlockerService(blockedApps);
      } catch (e) {
        // Handle error silently
      }

      // Launch the app with timer using Android's timer system
      final sessionDuration = selectedMinutes.value * 60;

      try {
        // Use the pause channel since we're in PauseActivity
        await PlatformService.launchAppWithTimerViaPause(
            lockedPackageName!, sessionDuration);
        print(
            'TIMER ON: ${lockedPackageName} for ${selectedMinutes.value} minutes');
        Get.back();

        // Log analytics
        await AnalyticsService.to.logPauseSession(selectedMinutes.value);
      } catch (e) {
        // Show error to user
        Get.snackbar(
          'Launch Error',
          'Could not open app. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );

        // Re-add the app to blocked list since launch failed
        blockedApps.add(lockedPackageName!);
        await prefs.setStringList("blocked_apps", blockedApps);
        await PlatformService.startBlockerService(blockedApps);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void blockApp() async {
    if (lockedPackageName != null) {
      await AppCountService.incrementAppCount(lockedPackageName!);
      await PlatformService.permanentlyBlockApp(lockedPackageName!);
      // Reset the pause flag since the user is taking action
      try {
        await PlatformService.resetPauseFlag(lockedPackageName!);
      } catch (e) {
        // Handle error silently
      }
    }
    await const MethodChannel(
      'com.detach.app/pause',
    ).invokeMethod('goToHomeAndFinish');
  }

  void continueApp() async {
    AnalyticsService.to.logPauseSessionInterrupted();

    // Reset the pause flag since the user is taking action
    if (lockedPackageName != null) {
      try {
        await PlatformService.resetPauseFlag(lockedPackageName!);
      } catch (e) {
        // Handle error silently
      }
    }

    // Transition to timer view
    showTimer.value = true;
    showButtons.value = false; // Hide buttons when showing timer
    progressController.value = 0;
  }

  RxInt attemptsToday = 0.obs;
  String? lockedPackageName;
  RxString appName = ''.obs;
  List<AppInfo> allApps = [];
  RxBool showButtons = false.obs;
  bool _isTimerExpired = false; // Track timer expiration state

  @override
  void onInit() {
    super.onInit();

    // Try multiple ways to get the package name
    lockedPackageName = Get.parameters['package'];
    if (lockedPackageName == null || lockedPackageName!.isEmpty) {
      // Try parsing from raw route
      final route = Get.rawRoute?.toString() ?? '';
      final packageMatch = RegExp(r'package=([^&]+)').firstMatch(route);
      if (packageMatch != null) {
        lockedPackageName = packageMatch.group(1);
      }
    }

    // Set up method channel listener for timer expiration
    const MethodChannel('com.detach.app/pause')
        .setMethodCallHandler((call) async {
      print(
          'DEBUG: Method channel call received: ${call.method} with args: ${call.arguments}');

      if (call.method == 'timerExpired') {
        // Handle timer expiration
        print('DEBUG: Timer expired method channel call received');
        _handleTimerExpiration();
      } else if (call.method == 'initializePause') {
        final packageName = call.arguments['packageName'];
        final isTimerExpired = call.arguments['timerExpired'] ?? false;
        final timerState = call.arguments['timerState'];

        print(
            'DEBUG: Initialize pause method channel call received - package: $packageName, timerExpired: $isTimerExpired, timerState: $timerState');

        // Initialize the pause screen with the provided data
        _initializeFromAndroid(packageName, isTimerExpired);
      }
    });

    // Debug: Print all parameters received
    print('DEBUG: Get.parameters = ${Get.parameters}');
    print('DEBUG: Get.rawRoute = ${Get.rawRoute}');
    print('DEBUG: Get.currentRoute = ${Get.currentRoute}');

    // Check for timer expiration from multiple sources
    bool timerExpired = false;

    // Check Get.parameters first
    if (Get.parameters['timer_expired'] == 'true') {
      print('DEBUG: Found timer_expired=true in Get.parameters');
      timerExpired = true;
      _isTimerExpired = true;
    }

    // Check route string
    final route = Get.rawRoute?.toString() ?? '';
    if (route.contains('timer_expired=true')) {
      print('DEBUG: Found timer_expired=true in route string');
      timerExpired = true;
      _isTimerExpired = true;
    }

    // Check intent extras (for Android direct launch)
    if (Get.parameters['timer_state'] == 'expired') {
      print('DEBUG: Found timer_state=expired in Get.parameters');
      timerExpired = true;
      _isTimerExpired = true;
    }

    if (lockedPackageName == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(AppRoutes.home);
      });
      return;
    }

    if (timerExpired) {
      print('TIMER EXPIRED: Detected timer expiration, showing pause flow');
      // Force the correct state for timer expiration
      _forcePauseScreenState();

      // Ensure we start fresh with water animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (waterController.status != AnimationStatus.forward) {
          waterController.forward();
        }
      });
    } else {
      print('NORMAL FLOW: Showing normal pause flow');
      showTimer.value = false;
      showButtons.value = false; // Start with water animation
    }

    if (lockedPackageName != null) {
      checkEarlyClose(lockedPackageName!);
    }

    AnalyticsService.to.logScreenView('pause_page');
    AnalyticsService.to.logAppBlocked(lockedPackageName!);

    waterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    waterAnimation = Tween<double>(begin: 0.0, end: 1.45).animate(
      CurvedAnimation(parent: waterController, curve: Curves.easeInOut),
    );
    waterController.forward();
    waterController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        waterController.reverse();
      }
      if (status == AnimationStatus.dismissed) {
        showButtons.value = true;
      }
    });

    progressController = AnimationController(
      vsync: this,
      duration: Duration(minutes: maxMinutes),
    );
    progressAnim = Tween<double>(begin: 0, end: 1).animate(progressController)
      ..addListener(() {
        // No-op, handled by Obx
      });

    _initializeAppData();
  }

  void _forcePauseScreenState() {
    print('FORCE PAUSE: Setting showTimer=false, showButtons=false');
    showTimer.value = false;
    showButtons.value = false;
  }

  void _handleTimerExpiration() {
    print('TIMER EXPIRED: Method channel timer expiration detected');
    _isTimerExpired = true; // Set the flag

    // Force the correct state for timer expiration
    _forcePauseScreenState();

    // Ensure water animation starts fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (waterController.status != AnimationStatus.forward) {
        waterController.forward();
      }
    });
  }

  void _initializeFromAndroid(String packageName, bool isTimerExpired) {
    // Set the package name
    lockedPackageName = packageName;

    if (isTimerExpired) {
      print('Timer expired detected from Android - showing pause flow');
      _isTimerExpired = true; // Set the flag
      // Force the correct state for timer expiration
      _forcePauseScreenState();

      // Ensure we start fresh with water animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (waterController.status != AnimationStatus.forward) {
          waterController.forward();
        }
      });

      // Add periodic check to ensure correct state during timer expiration
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (showTimer.value && _isTimerExpired) {
          _forcePauseScreenState();
        }
        // Stop the timer after 10 seconds
        if (timer.tick >= 10) {
          timer.cancel();
        }
      });
    } else {
      print('Normal pause flow - showing water animation');
      print('Setting showTimer.value = false for normal flow');
      showTimer.value = false;
      print('Setting showButtons.value = false for normal flow');
      showButtons.value = false; // Start with water animation
    }

    // Initialize app data
    _initializeAppData();

    // Start water animation if not already running
    if (waterController.status != AnimationStatus.forward) {
      waterController.forward();
    }

    // Log analytics
    AnalyticsService.to.logScreenView('pause_page');
    AnalyticsService.to.logAppBlocked(lockedPackageName!);
  }

  Future<void> _initializeAppData() async {
    if (lockedPackageName != null) {
      try {
        allApps = await InstalledApps.getInstalledApps(true, true);
        appName.value = AppCountService.getAppNameFromPackage(
          lockedPackageName!,
          allApps,
        );
        attemptsToday.value = await AppCountService.getAppCount(
          lockedPackageName!,
        );
      } catch (e) {
        appName.value = lockedPackageName!;
      }
    }
  }

  @override
  void onClose() {
    // Send broadcast to notify that pause screen is closed
    if (lockedPackageName != null) {
      try {
        const MethodChannel('com.detach.app/pause')
            .invokeMethod('pauseScreenClosed', {
          'package_name': lockedPackageName,
        });
        print('TIMER OFF: ${lockedPackageName}');
      } catch (e) {
        // Handle error silently
      }
    }

    waterController.dispose();
    progressController.dispose();
    super.onClose();
  }
}
