import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../pages/splash_page.dart';
import '../pages/permission_handler/bindings/permission_binding.dart';
import '../pages/permission_handler/view/permission_view.dart';
import '../pages/home/bindings/home_binding.dart';
import '../pages/home/view/home_view.dart';
import '../pages/pause/bindings/pause_binding.dart';
import '../pages/pause/views/pause_view.dart';
import 'app_routes.dart';
class PauseMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    // If the route is a pause route with a package parameter, allow it
    if (route != null &&
        route.startsWith(AppRoutes.pause) &&
        route.contains('?package=')) {
      return null;
    }
    // For all other routes, check if we're in a pause state
    // For now, just allow all other routes
    return null;
  }
  @override
  GetPage? onPageCalled(GetPage? page) {
    return page;
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
