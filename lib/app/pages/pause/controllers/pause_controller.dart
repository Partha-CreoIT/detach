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
    print('=== startCountdown() called ===');
    print('Current showTimer.value: ${showTimer.value}');
    print('Current showButtons.value: ${showButtons.value}');

    // Check if this is a timer expiration case - if so, don't start countdown
    final route = Get.rawRoute?.toString() ?? '';
    bool timerExpired = route.contains('timer_expired=true') ||
        Get.parameters['timer_expired'] == 'true';

    if (timerExpired) {
      print(
          'WARNING: startCountdown() called during timer expiration - this should not happen!');
      print('Ignoring startCountdown request during timer expiration');
      return; // Don't proceed with countdown
    }

    try {
      if (lockedPackageName == null) {
        print('No locked package name, cannot start countdown');
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
    print('=== continueApp() called ===');
    print('Current showTimer.value: ${showTimer.value}');
    print('Current showButtons.value: ${showButtons.value}');

    // Check if this is a timer expiration case - if so, don't show timer view
    final route = Get.rawRoute?.toString() ?? '';
    bool timerExpired = route.contains('timer_expired=true') ||
        Get.parameters['timer_expired'] == 'true';

    if (timerExpired) {
      print(
          'WARNING: continueApp() called during timer expiration - this should not happen!');
      print('Keeping showTimer.value = false to show pause screen instead');
      return; // Don't proceed with timer view
    }

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
    print('Setting showTimer.value = true');
    showTimer.value = true;
    print('Setting showButtons.value = false');
    showButtons.value = false; // Hide buttons when showing timer
    progressController.value = 0;

    print('Transitioning to timer view for ${lockedPackageName}');
    print('Final showTimer.value: ${showTimer.value}');
    print('Final showButtons.value: ${showButtons.value}');
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
    print('=== PauseController.onInit() called ===');
    print('Get.parameters: ${Get.parameters}');
    print('Get.rawRoute: ${Get.rawRoute}');
    print('Get.rawRoute.toString(): ${Get.rawRoute?.toString()}');
    print('Get.currentRoute: ${Get.currentRoute}');
    print('Get.routing.current: ${Get.routing.current}');

    // Try multiple ways to get the package name
    lockedPackageName = Get.parameters['package'];
    if (lockedPackageName == null || lockedPackageName!.isEmpty) {
      // Try parsing from raw route
      final route = Get.rawRoute?.toString() ?? '';
      final packageMatch = RegExp(r'package=([^&]+)').firstMatch(route);
      if (packageMatch != null) {
        lockedPackageName = packageMatch.group(1);
        print('Extracted package name from route: $lockedPackageName');
      }
    }

    // Set up method channel listener for timer expiration
    const MethodChannel('com.detach.app/pause')
        .setMethodCallHandler((call) async {
      print('=== Method channel call received: ${call.method} ===');
      if (call.method == 'timerExpired') {
        print('Timer expired notification received from Android!');
        print('Package: ${call.arguments['packageName']}');
        print('Timer state: ${call.arguments['timerState']}');

        // Handle timer expiration
        _handleTimerExpiration();
      } else if (call.method == 'test') {
        print(
            'Test method channel message received: ${call.arguments['message']}');
      } else if (call.method == 'initializePause') {
        print('Initialize pause notification received from Android!');
        final packageName = call.arguments['packageName'];
        final isTimerExpired = call.arguments['timerExpired'] ?? false;

        print('Package: $packageName, Timer expired: $isTimerExpired');

        // Initialize the pause screen with the provided data
        _initializeFromAndroid(packageName, isTimerExpired);
      }
    });

    // Manually parse query parameters from the route
    final route = Get.rawRoute?.toString() ?? '';
    bool timerExpired = false;

    // Check both route string and Get.parameters
    if (route.contains('timer_expired=true') ||
        Get.parameters['timer_expired'] == 'true') {
      timerExpired = true;
      _isTimerExpired = true; // Set the flag
    }

    print('lockedPackageName: $lockedPackageName');
    print('timerExpired: $timerExpired');
    print('_isTimerExpired: $_isTimerExpired');
    print('Initial showTimer.value: ${showTimer.value}');
    print('Initial showButtons.value: ${showButtons.value}');

    if (lockedPackageName == null) {
      print('No package name provided, redirecting to home');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(AppRoutes.home);
      });
      return;
    }

    if (timerExpired) {
      print('Timer expired detected from Android - showing pause flow');
      // Force the correct state for timer expiration
      _forcePauseScreenState();

      // Ensure we start fresh with water animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (waterController.status != AnimationStatus.forward) {
          waterController.forward();
        }
      });
    } else {
      print('Normal pause flow - showing water animation');
      print('Setting showTimer.value = false for normal flow');
      showTimer.value = false;
      print('Setting showButtons.value = false for normal flow');
      showButtons.value = false; // Start with water animation
    }

    print('After initialization - showTimer.value: ${showTimer.value}');
    print('After initialization - showButtons.value: ${showButtons.value}');

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
      print('=== Water animation status changed: $status ===');
      if (status == AnimationStatus.completed) {
        print('Water animation completed, reversing...');
        waterController.reverse();
      }
      if (status == AnimationStatus.dismissed) {
        print('Water animation dismissed, showing buttons');
        print('Setting showButtons.value = true');
        showButtons.value = true;
        print('Final showButtons.value: ${showButtons.value}');
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

    // Add periodic check to ensure correct state during timer expiration
    if (_isTimerExpired) {
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (showTimer.value && _isTimerExpired) {
          print(
              'WARNING: showTimer.value is true during timer expiration - fixing...');
          _forcePauseScreenState();
        }
        // Stop the timer after 10 seconds
        if (timer.tick >= 10) {
          timer.cancel();
        }
      });
    }
  }

  void _forcePauseScreenState() {
    print('=== _forcePauseScreenState called ===');
    print('Forcing showTimer.value = false');
    showTimer.value = false;
    print('Forcing showButtons.value = false');
    showButtons.value = false;
    print(
        'Final state - showTimer.value: ${showTimer.value}, showButtons.value: ${showButtons.value}');
  }

  void _handleTimerExpiration() {
    print('=== _handleTimerExpiration called ===');
    print('Current showTimer.value: ${showTimer.value}');
    print('Current showButtons.value: ${showButtons.value}');

    _isTimerExpired = true; // Set the flag

    // Force the correct state for timer expiration
    _forcePauseScreenState();

    // Ensure water animation starts fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (waterController.status != AnimationStatus.forward) {
        print('Starting water animation for timer expiration');
        waterController.forward();
      } else {
        print('Water animation already running for timer expiration');
      }
    });

    print('Timer expired UI state set - showing pause screen flow');
    print('Final showTimer.value: ${showTimer.value}');
    print('Final showButtons.value: ${showButtons.value}');
  }

  void _initializeFromAndroid(String packageName, bool isTimerExpired) {
    print('=== _initializeFromAndroid called ===');
    print('Package: $packageName, Timer expired: $isTimerExpired');
    print('Current showTimer.value: ${showTimer.value}');
    print('Current showButtons.value: ${showButtons.value}');

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
          print('Starting water animation for timer expiration from Android');
          waterController.forward();
        } else {
          print(
              'Water animation already running for timer expiration from Android');
        }
      });

      // Add periodic check to ensure correct state during timer expiration
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (showTimer.value && _isTimerExpired) {
          print(
              'WARNING: showTimer.value is true during timer expiration - fixing...');
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

    print('After _initializeFromAndroid - showTimer.value: ${showTimer.value}');
    print(
        'After _initializeFromAndroid - showButtons.value: ${showButtons.value}');

    // Initialize app data
    _initializeAppData();

    // Start water animation if not already running
    if (waterController.status != AnimationStatus.forward) {
      print('Starting water animation from _initializeFromAndroid');
      waterController.forward();
    } else {
      print('Water animation already running from _initializeFromAndroid');
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
    print('=== PauseController.onClose() called ===');

    // Send broadcast to notify that pause screen is closed
    if (lockedPackageName != null) {
      try {
        const MethodChannel('com.detach.app/pause')
            .invokeMethod('pauseScreenClosed', {
          'package_name': lockedPackageName,
        });
        print('Sent pause screen closed broadcast for $lockedPackageName');
      } catch (e) {
        print('Error sending pause screen closed broadcast: $e');
      }
    }

    waterController.dispose();
    progressController.dispose();
    super.onClose();
  }
}
