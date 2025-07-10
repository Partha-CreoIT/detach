import 'package:detach/app/pages/app_list/bindings/app_list_binding.dart';
import 'package:detach/app/pages/app_list/view/app_list_view.dart';
import 'package:detach/app/pages/home/bindings/home_binding.dart';
import 'package:detach/app/pages/home/view/home_view.dart';
import 'package:detach/app/pages/pause_page.dart';
import 'package:detach/app/pages/permission_handler/bindings/permission_binding.dart';
import 'package:detach/app/pages/permission_handler/view/permission_view.dart';
import 'package:detach/app/pages/splash_page.dart';
import 'package:detach/services/theme_service.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  Get.put(ThemeService());
  Get.put(AnalyticsService());

  runApp(const DetachApp());
}

class DetachApp extends StatelessWidget {
  const DetachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeService>(
      builder:
          (themeService) => GetMaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Detach',
            themeMode: themeService.themeMode.value,
            theme: ThemeService.lightTheme,
            darkTheme: ThemeService.darkTheme,
            navigatorObservers: [
              AnalyticsService.to.firebaseAnalyticsObserver ?? GetObserver(),
            ],
            getPages: [
              GetPage(name: '/', page: () => const SplashPage()),
              GetPage(
                name: '/permission',
                page: () => const PermissionView(),
                binding: PermissionBinding(),
              ),
              GetPage(
                name: '/apps',
                page: () => const AppListView(),
                binding: AppListBinding(),
              ),
              GetPage(
                name: '/home',
                page: () => const HomeView(),
                binding: HomeBinding(),
              ),
              GetPage(name: '/pause', page: () => const PausePage()),
            ],
          ),
    );
  }
}
