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
    if (state == AppLifecycleState.resumed) {
      // Always check permissions when app is resumed
      _hasCheckedPermissions = false;
      _checkPermissionsAndNavigate();
    }
  }

  Future<void> _checkPermissionsAndNavigate() async {
    final currentRoute = Get.currentRoute;

    // Bypass permission check if current route is /pause (for block screen)
    if (currentRoute.startsWith(AppRoutes.pause)) {
      return;
    }

    // Mark that we've checked permissions
    _hasCheckedPermissions = true;

    // Check all permissions
    final hasUsage = await _permissionService.hasUsagePermission();
    final hasOverlay = await _permissionService.hasOverlayPermission();
    final hasBattery = await _permissionService.hasBatteryOptimizationIgnored();

    // If all permissions are granted, navigate to home
    if (hasUsage && hasOverlay && hasBattery) {
      await AnalyticsService.to.logFeatureUsage('all_permissions_granted');
      Get.offAllNamed(AppRoutes.home);
      return;
    }

    // Otherwise, navigate to the first missing permission
    if (!hasUsage) {
      _navigateToPage(0);
      return;
    }
    if (!hasOverlay) {
      _navigateToPage(1);
      return;
    }
    if (!hasBattery) {
      _navigateToPage(2);
      return;
    }
  }

  void _navigateToPage(int page) {
    currentPage.value = page;
    pageController.jumpToPage(page);
  }

  Future<void> openUsageSettings() async {
    await AnalyticsService.to.logPermissionRequest('usage_stats');
    await PermissionService.openUsageSettings();
    // Reset permission check flag to check when user returns
    _hasCheckedPermissions = false;
  }

  Future<void> openOverlaySettings() async {
    await AnalyticsService.to.logPermissionRequest('overlay');
    await PermissionService.openOverlaySettings();
    // Reset permission check flag to check when user returns
    _hasCheckedPermissions = false;
  }

  Future<void> openBatteryOptimizationSettings() async {
    await AnalyticsService.to.logPermissionRequest('battery_optimization');
    await PermissionService.openBatteryOptimizationSettings();
    // Reset permission check flag to check when user returns
    _hasCheckedPermissions = false;
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
