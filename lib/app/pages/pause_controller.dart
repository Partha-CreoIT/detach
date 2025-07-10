import 'dart:async';
import 'package:get/get.dart';
import 'package:detach/services/platform_service.dart';
import 'package:detach/services/app_count_service.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:flutter/material.dart';
import 'package:detach/app/routes/app_routes.dart';

class PauseController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late AnimationController waterController;
  late Animation<double> waterAnimation;

  Timer? timer;

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
      debugPrint(
        'PauseController: No package name provided, redirecting to home',
      );
      Get.offAllNamed(AppRoutes.home);
      return;
    }

    AnalyticsService.to.logScreenView('pause_page');
    AnalyticsService.to.logAppBlocked(lockedPackageName!);
    waterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
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
    timer?.cancel();
    super.onClose();
  }
}
