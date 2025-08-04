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

  // Reactive variables for permission states
  final RxBool hasUsagePermission = false.obs;
  final RxBool hasOverlayPermission = false.obs;
  final RxBool hasBatteryPermission = false.obs;

  bool _hasCheckedPermissions = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    checkAndUpdatePermissions();
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
      // Add a small delay to ensure settings have been applied
      Future.delayed(const Duration(milliseconds: 500), () {
        checkAndUpdatePermissions();
        _checkPermissionsAndNavigate();
      });
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

    // Check all permissions and update reactive variables
    await checkAndUpdatePermissions();

    // If all permissions are granted, navigate to how to use page
    if (hasUsagePermission.value && hasOverlayPermission.value && hasBatteryPermission.value) {
      await AnalyticsService.to.logFeatureUsage('all_permissions_granted');
      _navigateToPage(3); // Navigate to "How to Use" page
      return;
    }

    // Otherwise, navigate to the first missing permission
    if (!hasUsagePermission.value) {
      _navigateToPage(0);
      return;
    }
    if (!hasOverlayPermission.value) {
      _navigateToPage(1);
      return;
    }
    if (!hasBatteryPermission.value) {
      _navigateToPage(2);
      return;
    }
  }

  void _navigateToPage(int page) {
    currentPage.value = page;
    pageController.jumpToPage(page);
  }

  // Method to move to next page only if current permission is granted
  Future<void> moveToNextPage() async {
    // First check and update all permissions
    await checkAndUpdatePermissions();

    // Check current permission status
    bool canProceed = false;

    switch (currentPage.value) {
      case 0:
        canProceed = hasUsagePermission.value;
        break;
      case 1:
        canProceed = hasOverlayPermission.value;
        break;
      case 2:
        canProceed = hasBatteryPermission.value;
        break;
      case 3:
        // On the last page, navigate to main navigation
        Get.offAllNamed(AppRoutes.mainNavigation);
        return;
    }

    if (canProceed && currentPage.value < 3) {
      currentPage.value++;
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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

  /// Check and update permission states
  Future<void> checkAndUpdatePermissions() async {
    final hasUsage = await _permissionService.hasUsagePermission();
    final hasOverlay = await _permissionService.hasOverlayPermission();
    final hasBattery = await _permissionService.hasBatteryOptimizationIgnored();

    hasUsagePermission.value = hasUsage;
    hasOverlayPermission.value = hasOverlay;
    hasBatteryPermission.value = hasBattery;

    // Check if all permissions are granted and navigate accordingly
    _checkAndNavigateAfterPermissions();
  }

  /// Check if all permissions are granted and navigate to appropriate page
  void _checkAndNavigateAfterPermissions() {
    if (hasUsagePermission.value && hasOverlayPermission.value && hasBatteryPermission.value) {
      // All permissions granted, navigate to "How to Use" page
      if (currentPage.value < 3) {
        currentPage.value = 3;
        pageController.jumpToPage(3);
      }
    } else {
      // Navigate to first missing permission
      if (!hasUsagePermission.value && currentPage.value != 0) {
        currentPage.value = 0;
        pageController.jumpToPage(0);
      } else if (hasUsagePermission.value &&
          !hasOverlayPermission.value &&
          currentPage.value != 1) {
        currentPage.value = 1;
        pageController.jumpToPage(1);
      } else if (hasUsagePermission.value &&
          hasOverlayPermission.value &&
          !hasBatteryPermission.value &&
          currentPage.value != 2) {
        currentPage.value = 2;
        pageController.jumpToPage(2);
      }
    }
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
