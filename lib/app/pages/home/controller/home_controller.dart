import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:detach/services/platform_service.dart';
import 'package:detach/services/permission_service.dart';
import 'package:detach/services/database_service.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:detach/app/routes/app_routes.dart';
import 'package:figma_squircle/figma_squircle.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  final RxInt limitedAppsCount = 0.obs;
  final PermissionService _permissionService = PermissionService();
  final DatabaseService _databaseService = DatabaseService();
  // App list functionality
  final RxList<AppInfo> allApps = <AppInfo>[].obs;
  final RxList<String> selectedAppPackages = <String>[].obs;
  final RxList<AppInfo> filteredApps = <AppInfo>[].obs;
  final RxBool isLoading = true.obs;

  // Search query
  final RxString searchQuery = ''.obs;

  // Apps to exclude (system apps and specific packages)
  final Set<String> _excludedPackages = {
    // Google Play Services and related
    'com.google.android.gms',
    'com.google.android.gsf',
    'com.google.android.gms.policy_sidecar_aps',
    'com.google.android.partnersetup',

    // Android Auto
    'com.google.android.projection.gearhead',
    'com.android.car.dialer',
    'com.android.car.media',

    // System apps
    'com.android.vending', // Play Store (optional - remove if you want to include)
    'com.android.providers.media',
    'com.android.externalstorage',
    'com.android.providers.downloads',
    'com.android.providers.contacts',
    'com.android.providers.calendar',
    'com.android.systemui',
    'com.android.settings',
    'com.android.launcher',
    'com.android.launcher3',

    // WebView and TTS
    'com.google.android.webview',
    'com.android.webview',
    'com.google.android.tts',

    // Other system components
    'com.android.keychain',
    'com.android.certinstaller',
    'com.android.printspooler',
    'com.android.bluetoothmidiservice',
    'com.android.nfc',
    'com.android.se',

    // Samsung specific (if needed)
    'com.samsung.android.bixby.agent',
    'com.samsung.android.app.spage',
    'com.sec.android.app.launcher',

    // Add more packages as needed
  };

  // Apps to always include even if they're system apps
  final Set<String> _alwaysInclude = {
    'com.google.android.youtube',
    'com.android.camera',
    'com.android.camera2',
    'com.android.gallery3d',
    'com.android.calendar',
    'com.android.contacts',
    'com.google.android.dialer',
    'com.android.dialer',
    'com.android.mms',
    'com.google.android.apps.messaging',
    'com.android.calculator2',
    'com.google.android.calculator',
    'com.android.music',
    'com.google.android.music',
    'com.android.chrome',
    'com.google.android.apps.maps',
    'com.google.android.gm', // Gmail
  };

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _loadLimitedAppsCount();
    _loadBlockedAppsAndApps();
    _logScreenView();
    _startBlockerServiceIfNeeded();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh blocked apps list when app is resumed with a small delay
      // to ensure Android service has time to update SharedPreferences
      Future.delayed(const Duration(milliseconds: 500), () {
        _refreshBlockedApps();
      });
    } else if (state == AppLifecycleState.detached) {
      // App is being killed, notify Android service to stop all timers
      _notifyAppKilled();
    }
  }

  void _notifyAppKilled() async {
    try {
      await PlatformService.notifyAppKilled();
    } catch (e) {
      // Handle error silently
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

    // Also get blocked apps from Android service to compare
    try {
      final androidBlockedApps = await PlatformService.getBlockedApps();

      // If Android service has more apps than SharedPreferences, use Android service data
      if (androidBlockedApps.length > blockedApps.length) {
        selectedAppPackages.assignAll(androidBlockedApps);
      } else {
        selectedAppPackages.assignAll(blockedApps);
      }
    } catch (e) {
      selectedAppPackages.assignAll(blockedApps);
    }
    await _loadApps();

    // Add a small delay to ensure allApps is fully populated
    await Future.delayed(const Duration(milliseconds: 100));
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
        false,
        true,
      );

      // Specific Google apps allow-list (only these apps will be shown)
      final allowedGoogleApps = [
        'com.google.android.apps.youtube.kids', // YouTube Kids
        'com.google.android.apps.youtube.creator', // YouTube Studio
        'com.google.android.apps.youtube.music', // YouTube Music
        'com.google.android.apps.photos', // Google Photos
        'com.google.android.youtube', // YouTube
        'com.google.android.apps.docs.editors.sheets', // Google Sheets
        'com.google.android.apps.docs.editors.docs', // Google Docs
        'com.google.android.apps.photosgo', // Gallery (Google Photos Go)
        'com.google.earth', // Google Earth
        'com.google.android.apps.docs', // Google Drive
        'com.google.android.apps.nbu.files', // Files by Google
        'com.google.android.dialer', // Phone by Google
        'com.google.android.apps.walletnfcrel', // Google Wallet
        'com.google.android.apps.chromecast.app', // Google Home
        'com.google.ar.lens', // Google Lens
        'com.chrome.dev', // Chrome Dev
        'com.android.chrome', // Google Chrome
        'com.google.android.apps.dynamite', // Google Chat
        'com.google.android.apps.maps', // Google Maps
        'com.google.chromeremotedesktop', // Chrome Remote Desktop
        'com.google.android.gm', // Gmail
        'com.google.android.youtube.tv', // YouTube for Android TV
        'com.google.android.apps.giant', // Google Analytics
        'com.google.android.GoogleCamera', // Pixel Camera
        'com.google.android.youtube.tvmusic', // YouTube Music for TV
        'com.google.android.gm.lite', // Gmail Go
        'com.google.android.apps.youtube.music.pwa', // YouTube Music for Chromebook
        'com.google.android.apps.automotive.youtube', // YouTube Automotive
        'com.google.android.aicore', // Android AICore
      ];

      List<AppInfo> filteredInstalledApps = [];

      // Step 1: Get only installed apps (non-system)
      List<AppInfo> userInstalledApps = await InstalledApps.getInstalledApps(
        true, // includeSystemApps = false
        true, // includeAppIcons = true
      );

      // Step 2: Get system apps separately
      List<AppInfo> systemApps = await InstalledApps.getInstalledApps(
        false,
        true, // includeAppIcons = true
      );

      // Step 3: Add all user-installed apps (excluding Detach app)
      for (AppInfo app in userInstalledApps) {
        if (app.packageName == 'com.detach.app') continue;
        filteredInstalledApps.add(app);
      }

      // Step 4: Check system apps against our Google allowlist
      for (AppInfo app in systemApps) {
        if (allowedGoogleApps.contains(app.packageName)) {
          // Only add if not already in the list (avoid duplicates)
          if (!filteredInstalledApps
              .any((existingApp) => existingApp.packageName == app.packageName)) {
            filteredInstalledApps.add(app);
          }
        }
      }

      // Sort apps alphabetically
      filteredInstalledApps.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      // Debug logging
      print('DEBUG: Found ${filteredInstalledApps.length} allowed Google apps:');
      for (final app in filteredInstalledApps) {
        print('  - ${app.name} (${app.packageName})');
      }

      allApps.assignAll(filteredInstalledApps);
      filteredApps.assignAll(filteredInstalledApps);
    } catch (e) {
      print('Error loading apps: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Helper method to check if an app has a launchable intent
  bool _hasLaunchableIntent(AppInfo app) {
    // Basic heuristics to determine if an app is launchable
    // Apps without proper names or with system-like names are probably not user-launchable
    if (app.name.isEmpty ||
        app.name.toLowerCase().contains('system') ||
        app.name.toLowerCase().contains('service') ||
        app.name.toLowerCase().contains('framework') ||
        app.packageName.contains('.provider') ||
        app.packageName.contains('.service') ||
        app.packageName.endsWith('.stub')) {
      return false;
    }

    return true;
  }

  // Method to manually add/remove packages from exclusion list
  void addToExcludedPackages(String packageName) {
    _excludedPackages.add(packageName);
  }

  void removeFromExcludedPackages(String packageName) {
    _excludedPackages.remove(packageName);
  }

  // Method to manually add/remove packages from always include list
  void addToAlwaysInclude(String packageName) {
    _alwaysInclude.add(packageName);
  }

  void removeFromAlwaysInclude(String packageName) {
    _alwaysInclude.remove(packageName);
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
      // Remove from locked apps table
      await _databaseService.deleteLockedApp(app.packageName);
    } else {
      selectedAppPackages.add(app.packageName);
      AnalyticsService.to.logAppBlocked(app.name);
      // Add to locked apps table (no default timings - will be set when user opens app)
      await _databaseService.upsertLockedApp(
        packageName: app.packageName,
        appName: app.name,
      );
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

  Future<void> _refreshBlockedApps() async {
    // Load current blocked apps from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final blockedApps = prefs.getStringList("blocked_apps") ?? [];

    // Update the selected apps list if it's different
    if (!_areListsEqual(selectedAppPackages, blockedApps)) {
      selectedAppPackages.assignAll(blockedApps);
      limitedAppsCount.value = blockedApps.length;
      // Trigger UI update
      selectedAppPackages.refresh();
      allApps.refresh();
      filteredApps.refresh();
    }
  }

  bool _areListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  // Computed getters for the UI
  List<AppInfo> get selectedApps {
    return allApps.where((app) => selectedAppPackages.contains(app.packageName)).toList();
  }

  // Method to refresh apps list (useful for debugging or manual refresh)
  Future<void> refreshAppsList() async {
    await _loadApps();
  }

  // Getters for debugging
  Set<String> get excludedPackages => Set.from(_excludedPackages);
  Set<String> get alwaysIncludePackages => Set.from(_alwaysInclude);
}
