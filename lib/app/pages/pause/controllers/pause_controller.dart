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
import 'package:detach/services/database_service.dart';

class PauseController extends GetxController with GetTickerProviderStateMixin {
  late AnimationController waterController;
  late Animation<double> waterAnimation;
  final DatabaseService _databaseService = DatabaseService();

  // Timer/slider logic for PauseView
  final RxBool showTimer = false.obs;
  final int maxMinutes = 30;
  final RxInt selectedMinutes = 5.obs;
  late AnimationController progressController;
  late Animation<double> progressAnim;
  String appNameStr = "";

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
            // Update database with early exit
            try {
              await _databaseService.updateAppUsage(
                packageName: packageName,
                sessionDurationSeconds: elapsedSeconds,
                isTimerExpired: false,
              );
              print('DEBUG: Updated database for early exit - $packageName, duration: ${elapsedSeconds}s');
            } catch (e) {
              print('Error updating database for early exit: $e');
            }

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
        // Set the timer in the database
        await _databaseService.setAppTimer(
          packageName: lockedPackageName!,
          timerMinutes: selectedMinutes.value,
        );

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
      // Update database with session end (user blocked app)
      try {
        final app = await _databaseService.getLockedApp(lockedPackageName!);
        if (app != null) {
          final totalLockedTime = (app['total_locked_time'] ?? 0) as int;
          final sessionDurationSeconds = totalLockedTime * 60; // Assume full session
          
          await _databaseService.updateAppUsage(
            packageName: lockedPackageName!,
            sessionDurationSeconds: sessionDurationSeconds,
            isTimerExpired: false,
          );
          print('DEBUG: Updated database for manual block - $lockedPackageName, duration: ${sessionDurationSeconds}s');
        }
      } catch (e) {
        print('Error updating database for manual block: $e');
      }

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

  void closeApp() async {
    if (lockedPackageName != null) {
      // Update database with session end (user closed app)
      try {
        final app = await _databaseService.getLockedApp(lockedPackageName!);
        if (app != null) {
          final totalLockedTime = (app['total_locked_time'] ?? 0) as int;
          final sessionDurationSeconds = totalLockedTime * 60; // Assume full session
          
          await _databaseService.updateAppUsage(
            packageName: lockedPackageName!,
            sessionDurationSeconds: sessionDurationSeconds,
            isTimerExpired: false,
          );
          print('DEBUG: Updated database for manual close - $lockedPackageName, duration: ${sessionDurationSeconds}s');
        }
      } catch (e) {
        print('Error updating database for manual close: $e');
      }

      await PlatformService.permanentlyBlockApp(lockedPackageName!);
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

      if (call.method == 'timerExpired') {
        _handleTimerExpiration();
      } else if (call.method == 'initializePause') {
        final packageName = call.arguments['packageName'];
        final isTimerExpired = call.arguments['timerExpired'] ?? false;
        final timerState = call.arguments['timerState'];
        _initializeFromAndroid(packageName, isTimerExpired);
      }
    });

    // Check for timer events from SharedPreferences
    _checkTimerEvents();


    // Check for timer expiration from multiple sources
    bool timerExpired = false;

    // Check Get.parameters first
    if (Get.parameters['timer_expired'] == 'true') {
      timerExpired = true;
      _isTimerExpired = true;
    }

    // Check route string
    final route = Get.rawRoute?.toString() ?? '';
    if (route.contains('timer_expired=true')) {
      timerExpired = true;
      _isTimerExpired = true;
    }

    // Check intent extras (for Android direct launch)
    if (Get.parameters['timer_state'] == 'expired') {
      timerExpired = true;
      _isTimerExpired = true;
    }

    if (lockedPackageName == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(AppRoutes.mainNavigation);
      });
      return;
    }

    if (timerExpired) {
      // Force the correct state for timer expiration
      _forcePauseScreenState();

      // Ensure we start fresh with water animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (waterController.status != AnimationStatus.forward) {
          waterController.forward();
        }
      });
    } else {
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
    showTimer.value = false;
    showButtons.value = false;
  }

  /// Check for timer events from SharedPreferences and update database
  Future<void> _checkTimerEvents() async {
    if (lockedPackageName == null) return;

    final prefs = await SharedPreferences.getInstance();
    final packageName = lockedPackageName!;

    // Check for timer started
    final timerStarted = prefs.getString("timer_started_$packageName");
    if (timerStarted == "true") {
      final duration = prefs.getInt("timer_duration_$packageName") ?? 0;
      await _databaseService.setAppTimer(
        packageName: packageName,
        timerMinutes: (duration / 60).round(),
      );
      print('DEBUG: Timer started for $packageName with duration ${duration}s');
      
      // Clear the flag
      await prefs.remove("timer_started_$packageName");
      await prefs.remove("timer_duration_$packageName");
    }

    // Check for timer stopped early
    final timerStopped = prefs.getString("timer_stopped_$packageName");
    if (timerStopped == "true") {
      final elapsedTime = prefs.getInt("timer_elapsed_$packageName") ?? 0;
      await _databaseService.updateAppUsage(
        packageName: packageName,
        sessionDurationSeconds: elapsedTime,
        isTimerExpired: false,
      );
      print('DEBUG: Timer stopped early for $packageName, elapsed: ${elapsedTime}s');
      
      // Clear the flag
      await prefs.remove("timer_stopped_$packageName");
      await prefs.remove("timer_elapsed_$packageName");
    }

    // Check for timer expired
    final timerExpired = prefs.getString("timer_expired_$packageName");
    if (timerExpired == "true") {
      // Get the actual elapsed time from SharedPreferences
      final elapsedTime = prefs.getInt("timer_elapsed_$packageName") ?? 0;
      final app = await _databaseService.getLockedApp(packageName);
      if (app != null) {
        final totalLockedTime = (app['total_locked_time'] ?? 0) as int;
        // Use the actual elapsed time, not the full timer duration
        final sessionDurationSeconds = elapsedTime > 0 ? elapsedTime : (totalLockedTime * 60);
        
        await _databaseService.updateAppUsage(
          packageName: packageName,
          sessionDurationSeconds: sessionDurationSeconds,
          isTimerExpired: true,
        );
        print('DEBUG: Timer expired for $packageName, actual duration: ${sessionDurationSeconds}s');
      }
      
      // Clear the flag
      await prefs.remove("timer_expired_$packageName");
      await prefs.remove("timer_elapsed_$packageName");
    }
  }

  void _handleTimerExpiration() async {
    _isTimerExpired = true; // Set the flag

    // Update database with timer completion
    if (lockedPackageName != null) {
      try {
        // Get the actual elapsed time from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final elapsedTime = prefs.getInt("timer_elapsed_${lockedPackageName}") ?? 0;
        
        // Get the timer duration from the database
        final app = await _databaseService.getLockedApp(lockedPackageName!);
        if (app != null) {
          final totalLockedTime = (app['total_locked_time'] ?? 0) as int;
          // Use the actual elapsed time, not the full timer duration
          final sessionDurationSeconds = elapsedTime > 0 ? elapsedTime : (totalLockedTime * 60);
          
          // Update app usage in database
          await _databaseService.updateAppUsage(
            packageName: lockedPackageName!,
            sessionDurationSeconds: sessionDurationSeconds,
            isTimerExpired: true,
          );
          
          print('DEBUG: Updated database for timer expiration - $lockedPackageName, actual duration: ${sessionDurationSeconds}s');
        }
      } catch (e) {
        print('Error updating database for timer expiration: $e');
      }
    }

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
      showTimer.value = false;
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
        allApps = await InstalledApps.getInstalledApps(false, true);
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
      } catch (e) {
        // Handle error silently
      }
    }

    waterController.dispose();
    progressController.dispose();
    super.onClose();
  }
}
