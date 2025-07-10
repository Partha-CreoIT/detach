import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../pages/splash_page.dart';
import '../pages/permission_handler/bindings/permission_binding.dart';
import '../pages/permission_handler/view/permission_view.dart';
import '../pages/home/bindings/home_binding.dart';
import '../pages/home/view/home_view.dart';
import '../pages/pause_binding.dart';
import '../pages/pause_view.dart';
import 'app_routes.dart';

class PauseMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    // If navigating to pause, allow. Otherwise, block if pause is active.
    // You can implement logic here to check if pause should take over.
    return null;
  }
}

class AppPages {
  static final pages = [
    GetPage(name: AppRoutes.splash, page: () => const SplashPage()),
    GetPage(
      name: AppRoutes.permission,
      page: () => const PermissionView(),
      binding: PermissionBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.pause,
      page: () => const PauseView(),
      binding: PauseBinding(),
      middlewares: [PauseMiddleware()],
    ),
  ];
}
