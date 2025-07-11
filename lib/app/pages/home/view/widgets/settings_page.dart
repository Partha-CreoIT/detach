import 'package:detach/services/platform_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../../services/theme_service.dart';
import '../../../../../services/analytics_service.dart';
import '../../../../../services/permission_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String appVersion = '';
  String appName = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        appVersion = packageInfo.version;
        appName = packageInfo.appName;
      });
    } catch (e) {
      setState(() {
        appVersion = '1.0.0';
        appName = 'Detach';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // App Settings Section
                Text(
                  'App Settings',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Theme Toggle
                GetBuilder<ThemeService>(
                  builder:
                      (themeService) => Card(
                        child: ListTile(
                          leading: Icon(
                            themeService.isDarkMode.value
                                ? Icons.dark_mode
                                : Icons.light_mode,
                            color:
                                themeService.isDarkMode.value
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).primaryColor,
                          ),
                          title: const Text('Theme'),
                          subtitle: Text(
                            themeService.isDarkMode.value
                                ? 'Dark Mode'
                                : 'Light Mode',
                          ),
                          trailing: Switch(
                            value: themeService.isDarkMode.value,
                            onChanged: (value) {
                              themeService.toggleTheme();
                              AnalyticsService.to.logFeatureUsage(
                                'theme_changed',
                              );
                            },
                          ),
                        ),
                      ),
                ),

                const SizedBox(height: 16),

                // Permissions Section
                Text(
                  'Permissions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Usage Access Permission
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.analytics),
                    title: const Text('Usage Access'),
                    subtitle: const Text('Monitor app usage'),
                    trailing: FutureBuilder<bool>(
                      future: PermissionService().hasUsagePermission(),
                      builder: (context, snapshot) {
                        return Icon(
                          snapshot.data == true
                              ? Icons.check_circle
                              : Icons.error,
                          color:
                              snapshot.data == true ? Colors.green : Colors.red,
                        );
                      },
                    ),
                    onTap: () async {
                      await PermissionService.openUsageSettings();
                      AnalyticsService.to.logFeatureUsage(
                        'permission_settings_opened',
                      );
                    },
                  ),
                ),

                // Accessibility Permission
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.accessibility),
                    title: const Text('Accessibility'),
                    subtitle: const Text('Block apps automatically'),
                    trailing: FutureBuilder<bool>(
                      future: PermissionService().hasAccessibilityPermission(),
                      builder: (context, snapshot) {
                        return Icon(
                          snapshot.data == true
                              ? Icons.check_circle
                              : Icons.error,
                          color:
                              snapshot.data == true ? Colors.green : Colors.red,
                        );
                      },
                    ),
                    onTap: () async {
                      await PermissionService.openAccessibilitySettings();
                      AnalyticsService.to.logFeatureUsage(
                        'permission_settings_opened',
                      );
                    },
                  ),
                ),

                // Overlay Permission
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.layers),
                    title: const Text('Overlay'),
                    subtitle: const Text('Show pause screen'),
                    trailing: FutureBuilder<bool>(
                      future: PermissionService().hasOverlayPermission(),
                      builder: (context, snapshot) {
                        return Icon(
                          snapshot.data == true
                              ? Icons.check_circle
                              : Icons.error,
                          color:
                              snapshot.data == true ? Colors.green : Colors.red,
                        );
                      },
                    ),
                    onTap: () async {
                      await PermissionService.openOverlaySettings();
                      AnalyticsService.to.logFeatureUsage(
                        'permission_settings_opened',
                      );
                    },
                  ),
                ),

                // Battery Optimization
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.battery_charging_full),
                    title: const Text('Battery Optimization'),
                    subtitle: const Text('Keep app running in background'),
                    trailing: FutureBuilder<bool>(
                      future:
                          PermissionService().hasBatteryOptimizationIgnored(),
                      builder: (context, snapshot) {
                        return Icon(
                          snapshot.data == true
                              ? Icons.check_circle
                              : Icons.error,
                          color:
                              snapshot.data == true ? Colors.green : Colors.red,
                        );
                      },
                    ),
                    onTap: () async {
                      await PermissionService.openBatteryOptimizationSettings();
                      AnalyticsService.to.logFeatureUsage(
                        'permission_settings_opened',
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // App Information Section
                Text(
                  'App Information',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // App Version
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('App Version'),
                    subtitle: Text('Version $appVersion'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),

                // App Name
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.apps),
                    title: const Text('App Name'),
                    subtitle: Text(appName),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),

                // About Section
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('About'),
                    subtitle: const Text('Learn more about Detach'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AnalyticsService.to.logFeatureUsage('about_opened');
                      // TODO: Navigate to about page or show dialog
                    },
                  ),
                ),

                // Privacy Policy
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    subtitle: const Text('How we protect your data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AnalyticsService.to.logFeatureUsage(
                        'privacy_policy_opened',
                      );
                      // TODO: Navigate to privacy policy page
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Debug Section
                Text(
                  'Debug',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Check Service Status
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.bug_report),
                    title: const Text('Check Service Status'),
                    subtitle: const Text('Verify blocker service is running'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final isRunning =
                          await PlatformService.isBlockerServiceRunning();
                      final blockedApps =
                          await PlatformService.getBlockedApps();
                      debugPrint('Blocker service running: $isRunning');
                      debugPrint('Blocked apps: $blockedApps');
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Footer
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      '© 2024 $appName. All rights reserved.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
