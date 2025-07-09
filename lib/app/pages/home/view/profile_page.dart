import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../services/theme_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Profile Header
              Center(
                child: Column(
                  children: [
                    // Profile Avatar
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.2),
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // User Name
                    Text(
                      'John Doe',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // User Email
                    Text(
                      'john.doe@example.com',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Settings Section
              Text(
                'Settings',
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
                          },
                        ),
                      ),
                    ),
              ),

              const SizedBox(height: 16),

              // App Info Section
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
                  leading: Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  title: const Text('App Version'),
                  subtitle: Text('Version $appVersion'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),

              const SizedBox(height: 16),

              // App Name
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.apps,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  title: const Text('App Name'),
                  subtitle: Text(appName),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),

              const Spacer(),

              // Footer
              Center(
                child: Text(
                  '© 2024 $appName. All rights reserved.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
