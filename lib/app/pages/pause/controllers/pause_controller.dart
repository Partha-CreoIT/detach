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
  final RxBool showCountdown = false.obs;
  final int maxMinutes = 30;
  final RxInt selectedMinutes = 5.obs;
  // Timer variables removed - timer now runs on Android
  late AnimationController progressController;
  late Animation<double> progressAnim;
  String appNameStr = "Google Docs";

  String get displayAppName =>
      appName.value.isNotEmpty ? appName.value : appNameStr;

  // Add these new variables to track app usage
  DateTime? _appStartTime;
  String? _currentSessionKey;

  // Save the session start time and details
  Future<void> _saveSessionStart(
      String packageName, int durationMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    _appStartTime = DateTime.now();
    _currentSessionKey = 'app_session_$packageName';

    // Save session details
    await prefs.setString(
        _currentSessionKey!, _appStartTime!.toIso8601String());
    await prefs.setInt('${_currentSessionKey!}_duration', durationMinutes * 60);
  }

  // Check if an app was closed early and handle accordingly
  Future<void> checkEarlyClose(String packageName) async {
    try {
      print('=== checkEarlyClose called for $packageName ===');

      final prefs = await SharedPreferences.getInstance();
      final sessionStartKey = 'app_session_${packageName}_start';
      final sessionDurationKey = 'app_session_${packageName}_duration';

      print('Looking for session keys: $sessionStartKey, $sessionDurationKey');
      print('Contains sessionStartKey: ${prefs.containsKey(sessionStartKey)}');

      // Check if we have a saved session
      if (prefs.containsKey(sessionStartKey)) {
        final startTimeStr = prefs.getString(sessionStartKey);
        final totalDuration = prefs.getInt(sessionDurationKey) ?? 0;

        print('Found startTimeStr: $startTimeStr');
        print('Total duration: $totalDuration');

        if (startTimeStr != null) {
          final startTimeMillis = int.tryParse(startTimeStr) ?? 0;
          final startTime =
              DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
          final now = DateTime.now();
          final elapsedSeconds = now.difference(startTime).inSeconds;

          print('Session details:');
          print('  - Start time: $startTime');
          print('  - Current time: $now');
          print('  - Elapsed seconds: $elapsedSeconds');
          print('  - Total duration: $totalDuration');

          // If the app was closed before the timer finished
          if (elapsedSeconds < totalDuration) {
            print('*** APP $packageName CLOSED EARLY! RE-BLOCKING APP ***');

            // Add the app back to blocked list
            final blockedApps =
                prefs.getStringList("blocked_apps")?.toList() ?? [];
            print('Current blocked apps before adding: $blockedApps');

            if (!blockedApps.contains(packageName)) {
              blockedApps.add(packageName);
              print('Added $packageName to blocked apps: $blockedApps');
              await prefs.setStringList("blocked_apps", blockedApps);

              // Update the blocker service with new list
              try {
                await PlatformService.startBlockerService(blockedApps);
                print('Updated blocker service with new blocked apps list');
              } catch (e) {
                print('Error updating blocker service: $e');
              }
            } else {
              print('$packageName was already in blocked apps list');
            }
          } else {
            print(
                'App $packageName was closed after timer finished, no re-blocking needed');
          }

          // Clear the session data
          print('Clearing session data for $packageName');
          await prefs.remove(sessionStartKey);
          await prefs.remove(sessionDurationKey);
          print('Session data cleared');
        }
      } else {
        // print('No active session found for $packageName');
      }

      print('=== checkEarlyClose completed for $packageName ===');
    } catch (e) {
      print('Error in checkEarlyClose: $e');
    }
  }

  void startCountdown() async {
    try {
      print('=== startCountdown called ===');
      print('lockedPackageName: $lockedPackageName');
      print('selectedMinutes: ${selectedMinutes.value}');

      if (lockedPackageName == null) {
        print('Error: lockedPackageName is null');
        return;
      }

      // Reset the pause flag so the pause screen can show again for this app
      try {
        print('Resetting pause flag for $lockedPackageName');
        await PlatformService.resetPauseFlag(lockedPackageName!);
      } catch (e) {
        print('Error resetting pause flag: $e');
      }

      // Remove the app from blocked list temporarily
      final prefs = await SharedPreferences.getInstance();
      final blockedApps = prefs.getStringList("blocked_apps")?.toList() ?? [];

      print('Current blocked apps before removing: $blockedApps');

      blockedApps.remove(lockedPackageName);
      await prefs.setStringList("blocked_apps", blockedApps);
      print('Removed $lockedPackageName from blocked apps: $blockedApps');

      // Reset the app block to prevent immediate re-blocking
      try {
        print('Resetting app block for $lockedPackageName');
        await PlatformService.resetAppBlock(lockedPackageName!);
      } catch (e) {
        print('Error resetting app block: $e');
      }

      // Update the blocker service with new list
      try {
        print('Updating blocker service with apps: $blockedApps');
        await PlatformService.startBlockerService(blockedApps);
      } catch (e) {
        print('Error updating blocker service: $e');
      }

      // Launch the app with timer using Android's timer system
      final sessionDuration = selectedMinutes.value * 60;
      print(
          'Launching app $lockedPackageName with timer for $sessionDuration seconds');

      try {
        // Use the pause channel since we're in PauseActivity
        await PlatformService.launchAppWithTimerViaPause(
            lockedPackageName!, sessionDuration);
        print('App launch with timer successful');
        Get.back();

        // Log analytics
        await AnalyticsService.to.logPauseSession(selectedMinutes.value);
      } catch (e) {
        print('App launch with timer failed: $e');
        // Show error to user
        Get.snackbar(
          'Launch Error',
          'Could not open app. Error: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );

        // Re-add the app to blocked list since launch failed
        blockedApps.add(lockedPackageName!);
        await prefs.setStringList("blocked_apps", blockedApps);
        await PlatformService.startBlockerService(blockedApps);
      }
    } catch (e, stackTrace) {
      print('Error in startCountdown: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _handleTimeUp() async {
    // This method is no longer needed since the timer runs on Android
    // The Android service handles timer expiration and shows the pause screen
    print('_handleTimeUp called - this should not happen with Android timer');
  }

  void openApp() async {
    // This is now handled in startCountdown
  }

  void blockApp() async {
    if (lockedPackageName != null) {
      await AppCountService.incrementAppCount(lockedPackageName!);
      await PlatformService.permanentlyBlockApp(lockedPackageName!);
      // Reset the pause flag since the user is taking action
      try {
        await PlatformService.resetPauseFlag(lockedPackageName!);
      } catch (e) {}
    }
    await const MethodChannel(
      'com.detach.app/pause',
    ).invokeMethod('goToHomeAndFinish');
  }

  void continueApp() async {
    AnalyticsService.to.logPauseSessionInterrupted();
    showTimer.value = true;
    // Timer variables removed - timer now runs on Android
    progressController.value = 0;
  }

  RxInt start = 60.obs;
  RxInt attemptsToday = 0.obs;
  String? lockedPackageName;
  RxString appName = ''.obs;
  List<AppInfo> allApps = [];
  RxBool showButtons = false.obs;
  RxBool timerStarted = false.obs;

  @override
  void onInit() {
    super.onInit();
    lockedPackageName = Get.parameters['package'];
    // If no package name is provided, this is not a valid pause session
    if (lockedPackageName == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(AppRoutes.home);
      });
      return;
    }

    // Check if this is a timer expiration case
    final timerExpired = Get.parameters['timer_expired'] == 'true';
    if (timerExpired) {
      print('Timer expired - showing pause view instead of timer view');
      showTimer.value = false;
      showButtons.value = true;
    }

    // Check if this app was closed early in a previous session
    if (lockedPackageName != null) {
      print('Checking for early close on init for: $lockedPackageName');
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

  void startTimer() {
    timerStarted.value = true;
    AnalyticsService.to.logPauseSession(start.value);
    // Timer variables removed - timer now runs on Android
    // timer = Timer.periodic(const Duration(seconds: 1), (t) async {
    //   if (start.value == 0) {
    //     t.cancel();
    //     AnalyticsService.to.logPauseSessionCompleted(60);
    //     await PlatformService.closeBothApps();
    //     if (lockedPackageName != null) {
    //       Future.delayed(const Duration(milliseconds: 500), () async {
    //         await PlatformService.launchApp(lockedPackageName!);
    //       });
    //     }
    //   } else {
    //     start.value--;
    //   }
    // });
  }

  @override
  void onClose() {
    waterController.dispose();
    progressController.dispose();
    // timer?.cancel();
    super.onClose();
  }
}
