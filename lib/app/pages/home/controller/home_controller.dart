import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:detach/services/platform_service.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:detach/services/permission_service.dart';

class HomeController extends GetxController {
  final RxInt tabIndex = 0.obs;
  final RxInt limitedAppsCount = 0.obs;

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

    // Check if there's a tab parameter in the URL
    final tabParam = Get.parameters['tab'];
    if (tabParam != null) {
      final tabIndex = int.tryParse(tabParam);
      if (tabIndex != null && tabIndex >= 0 && tabIndex <= 1) {
        this.tabIndex.value = tabIndex;
      }
    }
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

  Future<void> _loadApps() async {
    try {
      isLoading.value = true;
      List<AppInfo> installedApps = await InstalledApps.getInstalledApps(
        true,
        true,
      );

      // Filter out the current app (Detach) from the list
      installedApps =
          installedApps
              .where((app) => app.packageName != 'com.example.detach')
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

  void changeTabIndex(int index) {
    tabIndex.value = index;
  }

  void toggleAppSelection(AppInfo app) async {
    if (selectedAppPackages.contains(app.packageName)) {
      selectedAppPackages.remove(app.packageName);
      AnalyticsService.to.logAppUnblocked(app.name);
    } else {
      selectedAppPackages.add(app.packageName);
      AnalyticsService.to.logAppBlocked(app.name);
    }

    // Save to SharedPreferences immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("blocked_apps", selectedAppPackages.toList());

    // Update limited apps count
    limitedAppsCount.value = selectedAppPackages.length;

    // Trigger UI update
    selectedAppPackages.refresh();
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

  void clearAllSelected() async {
    selectedAppPackages.clear();
    selectedAppPackages.refresh();
    allApps.refresh();

    // Stop the blocker service since no apps are blocked
    await PlatformService.startBlockerService([]);
  }

  void saveApps() async {
    // Save selected apps to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("blocked_apps", selectedAppPackages.toList());

    // Start the blocker service with the selected apps
    if (selectedAppPackages.isNotEmpty) {
      await PlatformService.startBlockerService(selectedAppPackages.toList());
    }

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

  Future<void> _logScreenView() async {
    await AnalyticsService.to.logScreenView('home');
  }
}
