import 'package:detach/app/routes/app_pages.dart';
import 'package:detach/app/routes/app_routes.dart';
import 'package:detach/services/theme_service.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:detach/services/platform_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:detach/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:detach/app/pages/pause/views/pause_view.dart';
import 'package:detach/app/pages/pause/bindings/pause_binding.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Set preferred orientations to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Initialize Firebase with generated options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Initialize services
  final themeService = Get.put(ThemeService());
  Get.put(AnalyticsService());
  // Initialize status bar style
  themeService.updateStatusBarStyle();

  // Ensure blocker service is running if there are blocked apps
  await _ensureBlockerServiceRunning();

  runApp(const DetachApp());
}

Future<void> _ensureBlockerServiceRunning() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final blockedApps = prefs.getStringList("blocked_apps") ?? [];

    if (blockedApps.isNotEmpty) {
      print(
          'Found ${blockedApps.length} blocked apps, ensuring service is running...');
      await PlatformService.restartBlockerServiceIfNeeded(blockedApps);
    }
  } catch (e) {
    print('Error ensuring blocker service is running: $e');
  }
}

class DetachApp extends StatelessWidget {
  const DetachApp({super.key});
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final themeService = Get.find<ThemeService>();
      // Single status bar update when theme changes
      themeService.updateStatusBarStyle();
      return GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Detach',
        themeMode: themeService.themeMode.value,
        theme: ThemeService.lightTheme,
        darkTheme: ThemeService.darkTheme,
        navigatorObservers: [
          AnalyticsService.to.firebaseAnalyticsObserver!,
        ],
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
        onGenerateInitialRoutes: (String initialRoute) {
          print('=== DetachApp: onGenerateInitialRoutes called ===');
          print('Initial route: $initialRoute');

          // Check if this is a pause route from Android
          if (initialRoute.startsWith('/pause')) {
            print('=== DetachApp: Direct pause route detected ===');
            return [
              PageRouteBuilder(
                settings: RouteSettings(name: initialRoute),
                pageBuilder: (context, animation, secondaryAnimation) {
                  // Manually initialize the binding
                  PauseBinding().dependencies();
                  return const PauseView();
                },
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  // No transition - instant display
                  return child;
                },
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              )
            ];
          }

          // Default route handling
          return [];
        },
      );
    });
  }
}
