import 'package:detach/services/permission_service.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/app/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionController extends GetxController with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();
  final PageController pageController = PageController();
  final RxInt currentPage = 0.obs;
  bool _hasCheckedPermissions = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndNavigate();
    _logScreenView();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    pageController.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_hasCheckedPermissions) {
      _checkPermissionsAndNavigate();
    }
  }

  Future<void> _checkPermissionsAndNavigate() async {
    final currentRoute = Get.currentRoute;
    print('[DEBUG] PermissionController: currentRoute = ' + currentRoute);

    // Bypass permission check if current route is /pause (for block screen)
    if (currentRoute.startsWith(AppRoutes.pause)) {
      print(
        '[DEBUG] PermissionController: Bypassing permission check for /pause route',
      );
      return;
    }

    // Mark that we've checked permissions
    _hasCheckedPermissions = true;

    if (!(await _permissionService.hasUsagePermission())) {
      print(
        '[DEBUG] PermissionController: Missing usage permission, navigating to page 0',
      );
      _navigateToPage(0);
      return;
    }

    if (!(await _permissionService.hasOverlayPermission())) {
      print(
        '[DEBUG] PermissionController: Missing overlay permission, navigating to page 1',
      );
      _navigateToPage(1);
      return;
    }
    if (!(await _permissionService.hasBatteryOptimizationIgnored())) {
      print(
        '[DEBUG] PermissionController: Missing battery optimization, navigating to page 2',
      );
      _navigateToPage(2);
      return;
    }

    // All permissions are granted
    print(
      '[DEBUG] PermissionController: All permissions granted, navigating to /home',
    );
    Get.offAllNamed(AppRoutes.home);
  }

  void _navigateToPage(int page) {
    currentPage.value = page;
    pageController.jumpToPage(page);
  }

  Future<void> openUsageSettings() async {
    await AnalyticsService.to.logPermissionRequest('usage_stats');
    await PermissionService.openUsageSettings();
  }

  Future<void> openOverlaySettings() async {
    await AnalyticsService.to.logPermissionRequest('overlay');
    await PermissionService.openOverlaySettings();
  }

  Future<void> openBatteryOptimizationSettings() async {
    await AnalyticsService.to.logPermissionRequest('battery_optimization');
    await PermissionService.openBatteryOptimizationSettings();
  }

  /// Reset permission check flag to allow re-checking when user returns from settings
  void resetPermissionCheck() {
    _hasCheckedPermissions = false;
  }

  Future<void> _logScreenView() async {
    await AnalyticsService.to.logScreenView('permission_setup');
  }

  /// Set bypass flag when user clicks close button
  Future<void> setBypassPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bypassed_permissions', true);
  }
}
