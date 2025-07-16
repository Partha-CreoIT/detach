import 'package:detach/app/routes/app_pages.dart';
import 'package:detach/app/routes/app_routes.dart';
import 'package:detach/services/theme_service.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:detach/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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
  Get.put(ThemeService());
  Get.put(AnalyticsService());
  // Status bar style will be set by ThemeService based on current theme
  // No need to set it statically here
  runApp(const DetachApp());
}

class DetachApp extends StatelessWidget {
  const DetachApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeService>(
      builder: (themeService) {
        return Obx(() {
          // Update status bar style immediately when theme changes
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
          );
        });
      },
    );
  }
}
