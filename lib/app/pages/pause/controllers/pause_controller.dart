import 'dart:async';
import 'package:get/get.dart';
import 'package:detach/services/platform_service.dart';
import 'package:detach/services/app_count_service.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:flutter/material.dart';
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
  final RxInt selectedMinutes = 30.obs; // Changed from 5 to 30 as default
  // Timer variables removed - Android handles everything
  late AnimationController progressController;
  late Animation<double> progressAnim;
  String appNameStr = "Google Docs";
  String get displayAppName =>
      appName.value.isNotEmpty ? appName.value : appNameStr;
  // timeString removed - Android handles timer display

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
        print('No active session found for $packageName');
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
      print('Session duration will be: ${selectedMinutes.value * 60} seconds');

      // Reset the pause flag so the pause screen can show again for this app
      if (lockedPackageName != null) {
        try {
          print('Resetting pause flag for $lockedPackageName');
          await PlatformService.resetPauseFlag(lockedPackageName!);
        } catch (e) {
          print('Error resetting pause flag: $e');
        }
      }

      // First remove the app from blocked list temporarily
      if (lockedPackageName != null) {
        final prefs = await SharedPreferences.getInstance();
        final blockedApps = prefs.getStringList("blocked_apps")?.toList() ?? [];

        print('Current blocked apps before removing: $blockedApps');

        blockedApps.remove(lockedPackageName);
        await prefs.setStringList("blocked_apps", blockedApps);
        print('Removed $lockedPackageName from blocked apps: $blockedApps');

        // First reset the app block to prevent immediate re-blocking
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

        // Start tracking this app session in the native layer with Android timer
        final sessionDuration = selectedMinutes.value * 60;
        print(
            'Starting app session for $lockedPackageName with duration: $sessionDuration seconds');
        await PlatformService.startAppSession(
            lockedPackageName!, sessionDuration);

        // Launch the app
        await Future.delayed(const Duration(milliseconds: 500));

        print('Launching app: $lockedPackageName');
        await PlatformService.launchApp(lockedPackageName!);

        // Close the Flutter app completely - timer will continue in Android
        print(
            'Closing Flutter app - timer will continue in Android background');
        await PlatformService.closeFlutterApp();
      }

      // Log analytics
      await AnalyticsService.to.logPauseSession(selectedMinutes.value);
    } catch (e, stackTrace) {
      print('Error in startCountdown: $e');
    }
  }

  // _handleTimeUp is now handled by Android timer system
  // No need for Flutter timer handling since Android manages everything

  // Remove Flutter timer variables since Android handles everything
  // Timer? timer; - REMOVED
  // RxInt elapsedSeconds = 0.obs; - REMOVED
  // RxInt countdownSeconds = 0.obs; - REMOVED

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
    await MethodChannel(
      'com.detach.app/permissions',
    ).invokeMethod('goToHomeAndFinish');
  }

  void continueApp() async {
    AnalyticsService.to.logPauseSessionInterrupted();
    showTimer.value = true;
    progressController.value = 0;
  }

  // Method to update selected minutes from timer slider
  void updateSelectedMinutes(int minutes) {
    selectedMinutes.value = minutes;
    print('Updated selected minutes to: $minutes');
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
      Get.offAllNamed(AppRoutes.home);
      return;
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

  // startTimer removed - Android handles timer completely

  @override
  void onClose() {
    waterController.dispose();
    progressController.dispose();
    // timer?.cancel(); - removed since Android handles timer
    super.onClose();
  }
}
