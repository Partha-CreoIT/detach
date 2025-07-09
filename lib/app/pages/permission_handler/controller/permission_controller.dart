import 'package:detach/services/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PermissionController extends GetxController with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();
  final PageController pageController = PageController();
  final RxInt currentPage = 0.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndNavigate();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    pageController.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsAndNavigate();
    }
  }

  Future<void> _checkPermissionsAndNavigate() async {
    final currentRoute = Get.currentRoute;
    print('[DEBUG] PermissionController: currentRoute = ' + currentRoute);
    // Bypass permission check if current route is /pause (for block screen)
    if (currentRoute.startsWith('/pause')) {
      print(
        '[DEBUG] PermissionController: Bypassing permission check for /pause route',
      );
      return;
    }
    if (!(await _permissionService.hasUsagePermission())) {
      print(
        '[DEBUG] PermissionController: Missing usage permission, navigating to page 0',
      );
      _navigateToPage(0);
      return;
    }
    if (!(await _permissionService.hasAccessibilityPermission())) {
      print(
        '[DEBUG] PermissionController: Missing accessibility permission, navigating to page 1',
      );
      _navigateToPage(1);
      return;
    }
    if (!(await _permissionService.hasOverlayPermission())) {
      print(
        '[DEBUG] PermissionController: Missing overlay permission, navigating to page 2',
      );
      _navigateToPage(2);
      return;
    }
    if (!(await _permissionService.hasBatteryOptimizationIgnored())) {
      print(
        '[DEBUG] PermissionController: Missing battery optimization, navigating to page 3',
      );
      _navigateToPage(3);
      return;
    }

    // All permissions are granted
    print(
      '[DEBUG] PermissionController: All permissions granted, navigating to /home',
    );
    Get.offAllNamed('/home');
  }

  void _navigateToPage(int page) {
    currentPage.value = page;
    pageController.jumpToPage(page);
  }

  Future<void> openUsageSettings() async {
    await PermissionService.openUsageSettings();
  }

  Future<void> openAccessibilitySettings() async {
    await PermissionService.openAccessibilitySettings();
  }

  Future<void> openOverlaySettings() async {
    await PermissionService.openOverlaySettings();
  }

  Future<void> openBatteryOptimizationSettings() async {
    await PermissionService.openBatteryOptimizationSettings();
  }
}
