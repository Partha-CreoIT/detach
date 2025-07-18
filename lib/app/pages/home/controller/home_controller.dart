import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:detach/services/platform_service.dart';
import 'package:detach/services/permission_service.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:detach/app/routes/app_routes.dart';
import 'package:figma_squircle/figma_squircle.dart';

class HomeController extends GetxController {
  final RxInt limitedAppsCount = 0.obs;
  final PermissionService _permissionService = PermissionService();
  // App list functionality
  final RxList<AppInfo> allApps = <AppInfo>[].obs;
  final RxList<String> selectedAppPackages = <String>[].obs;
  final RxList<AppInfo> filteredApps = <AppInfo>[].obs;
  final RxBool isLoading = true.obs;
  @override
  void onInit() {
    super.onInit();
    _loadLimitedAppsCount();
    _loadBlockedAppsAndApps();
    _logScreenView();
    _startBlockerServiceIfNeeded();
  }

  Future<void> _loadLimitedAppsCount() async {
    final prefs = await SharedPreferences.getInstance();
    final blockedApps = prefs.getStringList("blocked_apps");
    limitedAppsCount.value = blockedApps?.length ?? 0;
  }

  Future<void> _loadBlockedAppsAndApps() async {
    // Load previously blocked apps from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final blockedApps = prefs.getStringList("blocked_apps") ?? [];
    selectedAppPackages.assignAll(blockedApps);
    await _loadApps();
  }

  Future<void> _startBlockerServiceIfNeeded() async {
    // Start the blocker service if there are blocked apps
    if (selectedAppPackages.isNotEmpty) {
      await PlatformService.startBlockerService(selectedAppPackages.toList());
    }
  }

  Future<void> _logScreenView() async {
    await AnalyticsService.to.logScreenView('home_page');
  }

  Future<void> _loadApps() async {
    try {
      isLoading.value = true;
      List<AppInfo> installedApps = await InstalledApps.getInstalledApps(
        true,
        true,
      );
      // Filter out the current app (Detach) from the list
      installedApps = installedApps
          .where((app) => app.packageName != 'com.detach.app')
          .toList();
      installedApps.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      allApps.assignAll(installedApps);
      filteredApps.assignAll(installedApps);
    } finally {
      isLoading.value = false;
    }
  }

  void toggleAppSelection(AppInfo app) async {
    // If user is trying to add an app (lock it), check permissions first
    if (!selectedAppPackages.contains(app.packageName)) {
      // Check if user has bypassed permissions
      final hasBypassed = await _checkAllPermissions();

      if (!hasBypassed) {
        // Check if all permissions are granted
        final hasAllPermissions = await _checkAllPermissions();

        if (!hasAllPermissions) {
          // Show permission bottom sheet and don't lock the app

          _showPermissionBottomSheet();
          return;
        }
      }
    }
    // If removing app or permissions are granted, proceed normally
    if (selectedAppPackages.contains(app.packageName)) {
      selectedAppPackages.remove(app.packageName);
      AnalyticsService.to.logAppUnblocked(app.name);
    } else {
      selectedAppPackages.add(app.packageName);
      AnalyticsService.to.logAppBlocked(app.name);
      // Notify native side that app was blocked to prevent immediate pause screen
      PlatformService.notifyAppBlocked(app.packageName);
    }
    // Always refresh the observable list
    selectedAppPackages.refresh();
    allApps.refresh();
    filteredApps.refresh();
    // Save to SharedPreferences and update the service
    await saveApps();
  }

  Future<void> _performAppBlocking(AppInfo app) async {
    selectedAppPackages.add(app.packageName);
    AnalyticsService.to.logAppBlocked(app.name);
    // Save to SharedPreferences immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("blocked_apps", selectedAppPackages.toList());
    // Update limited apps count
    limitedAppsCount.value = selectedAppPackages.length;
    // Trigger UI update
    selectedAppPackages.refresh();
    allApps.refresh();
  }

  Future<bool> _checkAllPermissions() async {
    final hasUsage = await _permissionService.hasUsagePermission();
    final hasOverlay = await _permissionService.hasOverlayPermission();
    final hasBattery = await _permissionService.hasBatteryOptimizationIgnored();

    return hasUsage && hasOverlay && hasBattery;
  }

  void _showPermissionBottomSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.security, size: 32, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            // Title
            const Text(
              'Permissions Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            // Description
            const Text(
              'To lock apps and control their usage, you need to grant the required permissions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                        ),
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Get.back();
                      Get.toNamed(AppRoutes.permission);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                        ),
                      ),
                    ),
                    child: const Text(
                      'Configure',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      isScrollControlled: true,
      enableDrag: true,
    );
  }

  void filterApps(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      filteredApps.assignAll(allApps);
    } else {
      filteredApps.assignAll(
        allApps.where(
          (app) => app.name.toLowerCase().contains(query.toLowerCase()),
        ),
      );
    }
  }

  // Check if user is searching
  bool get isSearching {
    return searchQuery.isNotEmpty;
  }

  // Search query
  final RxString searchQuery = ''.obs;
  void clearAllSelected() async {
    selectedAppPackages.clear();
    selectedAppPackages.refresh();
    allApps.refresh();
    // Stop the blocker service since no apps are blocked
    await PlatformService.startBlockerService([]);
  }

  Future<void> saveApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("blocked_apps", selectedAppPackages.toList());
    // Always update the blocker service, even if only one app is blocked
    await PlatformService.startBlockerService(selectedAppPackages.toList());
    // Update limited apps count
    limitedAppsCount.value = selectedAppPackages.length;
    // Log analytics
    await AnalyticsService.to.logFeatureUsage('apps_configured');
    await AnalyticsService.to.logEvent(
      name: 'apps_blocked_count',
      parameters: {'count': selectedAppPackages.length},
    );
  }

  // Computed getters for the UI
  List<AppInfo> get selectedApps {
    return allApps
        .where((app) => selectedAppPackages.contains(app.packageName))
        .toList();
  }
}
