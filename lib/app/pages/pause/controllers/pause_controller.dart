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
  final RxInt selectedMinutes = 5.obs;
  final RxInt elapsedSeconds = 0.obs;
  final RxInt countdownSeconds = 0.obs;
  late AnimationController progressController;
  late Animation<double> progressAnim;
  Timer? timer;
  String appNameStr = "Google Docs";
  String get displayAppName =>
      appName.value.isNotEmpty ? appName.value : appNameStr;
  String get timeString {
    final remaining = countdownSeconds.value - elapsedSeconds.value;
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void startCountdown() async {
    try {
      showCountdown.value = true;
      countdownSeconds.value = selectedMinutes.value * 60;
      elapsedSeconds.value = 0;
      progressController.duration = Duration(minutes: selectedMinutes.value);
      progressController.value = 0;
      timer?.cancel();
      // Reset the pause flag so the pause screen can show again for this app
      if (lockedPackageName != null) {
        try {
          await PlatformService.resetPauseFlag(lockedPackageName!);
        } catch (e) {}
      }
      // First remove the app from blocked list temporarily
      if (lockedPackageName != null) {
        final prefs = await SharedPreferences.getInstance();
        final blockedApps = prefs.getStringList("blocked_apps")?.toList() ?? [];

        blockedApps.remove(lockedPackageName);
        await prefs.setStringList("blocked_apps", blockedApps);

        // First reset the app block to prevent immediate re-blocking
        try {
          await PlatformService.resetAppBlock(lockedPackageName!);
        } catch (e) {}
        // Update the blocker service with new list
        try {
          await PlatformService.startBlockerService(blockedApps);
        } catch (e) {}
        // Launch the app
        await Future.delayed(const Duration(milliseconds: 500));

        await PlatformService.launchApp(lockedPackageName!);
        // Close the pause screen
        Get.back();
      }
      // Start the countdown timer
      timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        elapsedSeconds.value++;
        if (elapsedSeconds.value % 60 == 0) {
          HapticFeedback.mediumImpact();
        }
        if (elapsedSeconds.value >= countdownSeconds.value) {
          timer?.cancel();

          _handleTimeUp();
        }
        progressController.value =
            elapsedSeconds.value / countdownSeconds.value;
      });
      // Log analytics
      await AnalyticsService.to.logPauseSession(selectedMinutes.value);
    } catch (e, stackTrace) {}
  }

  void _handleTimeUp() async {
    try {
      if (lockedPackageName != null) {
        // Add the app back to blocked list
        final prefs = await SharedPreferences.getInstance();
        final blockedApps = prefs.getStringList("blocked_apps")?.toList() ?? [];

        if (!blockedApps.contains(lockedPackageName)) {
          blockedApps.add(lockedPackageName!);
          await prefs.setStringList("blocked_apps", blockedApps);

          // Update the blocker service with new list
          try {
            await PlatformService.startBlockerService(blockedApps);
          } catch (e) {}
        }
        // Close both apps and return to pause view

        await PlatformService.closeBothApps();
        // Reset states
        showTimer.value = false;
        showCountdown.value = false;
        showButtons.value = true;
        // Update attempts count
        attemptsToday.value = await AppCountService.getAppCount(
          lockedPackageName!,
        );
        // Log analytics
        AnalyticsService.to.logPauseSessionCompleted(countdownSeconds.value);
      }
    } catch (e, stackTrace) {}
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
    await MethodChannel(
      'com.detach.app/permissions',
    ).invokeMethod('goToHomeAndFinish');
  }

  void continueApp() async {
    AnalyticsService.to.logPauseSessionInterrupted();
    showTimer.value = true;
    elapsedSeconds.value = 0;
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
      Get.offAllNamed(AppRoutes.home);
      return;
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
    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (start.value == 0) {
        t.cancel();
        AnalyticsService.to.logPauseSessionCompleted(60);
        await PlatformService.closeBothApps();
        if (lockedPackageName != null) {
          Future.delayed(const Duration(milliseconds: 500), () async {
            await PlatformService.launchApp(lockedPackageName!);
          });
        }
      } else {
        start.value--;
      }
    });
  }

  @override
  void onClose() {
    waterController.dispose();
    progressController.dispose();
    timer?.cancel();
    super.onClose();
  }
}
