import 'package:detach/services/platform_service.dart';
import 'package:get/get.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detach/services/permission_service.dart';

class AppListController extends GetxController {
  final RxList<AppInfo> allApps = <AppInfo>[].obs;
  final RxList<String> selectedAppPackages = <String>[].obs;
  final RxList<AppInfo> filteredApps = <AppInfo>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool showSelectedApps = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadBlockedAppsAndApps();
  }

  Future<void> _loadBlockedAppsAndApps() async {
    // Load previously blocked apps from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final blockedApps = prefs.getStringList("blocked_apps") ?? [];
    selectedAppPackages.assignAll(blockedApps);
    await _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      isLoading.value = true;
      List<AppInfo> installedApps = await InstalledApps.getInstalledApps(
        true,
        true,
      );
      installedApps.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      allApps.assignAll(installedApps);
      filteredApps.assignAll(installedApps);
    } finally {
      isLoading.value = false;
    }
  }

  void toggleAppSelection(AppInfo app) {
    if (selectedAppPackages.contains(app.packageName)) {
      selectedAppPackages.remove(app.packageName);
    } else {
      selectedAppPackages.add(app.packageName);
    }
    allApps.refresh();
  }

  void filterApps(String query) {
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

  void saveAndStartService() async {
    // Save selected apps to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("blocked_apps", selectedAppPackages.toList());
    PlatformService.startBlockerService(selectedAppPackages.toList());
    Get.back(result: true);
  }

  void goBack() {
    Get.back(result: true);
  }

  Future<void> goToAddAppsWithPermissionCheck() async {
    final permissionService = PermissionService();
    final hasUsage = await permissionService.hasUsagePermission();
    final hasAccessibility =
        await permissionService.hasAccessibilityPermission();
    final hasOverlay = await permissionService.hasOverlayPermission();
    final hasBattery = await permissionService.hasBatteryOptimizationIgnored();
    if (!hasUsage || !hasAccessibility || !hasOverlay || !hasBattery) {
      Get.toNamed('/permission');
      return;
    }
    final result = await Get.toNamed('/apps');
    if (result == true) {
      // Optionally reload limited apps count or other state here
    }
  }
}
