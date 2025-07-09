import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/services/permission_service.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  Future<void> _checkPermissionsAndNavigate() async {
    debugPrint('SplashPage: Current route = ${Get.currentRoute}');

    // Don't redirect if we're already on the pause page
    if (Get.currentRoute.startsWith('/pause')) {
      debugPrint(
        'SplashPage: Already on pause page, skipping permission check',
      );
      return;
    }

    final permissionService = PermissionService();
    final hasUsage = await permissionService.hasUsagePermission();
    final hasAccessibility =
        await permissionService.hasAccessibilityPermission();
    final hasOverlay = await permissionService.hasOverlayPermission();
    final hasBattery = await permissionService.hasBatteryOptimizationIgnored();

    debugPrint(
      'SplashPage: Permissions check - Usage: $hasUsage, Accessibility: $hasAccessibility, Overlay: $hasOverlay, Battery: $hasBattery',
    );

    if (hasUsage && hasAccessibility && hasOverlay && hasBattery) {
      debugPrint('SplashPage: All permissions granted, navigating to home');
      Get.offAllNamed('/home');
    } else {
      debugPrint(
        'SplashPage: Missing permissions, navigating to permission page',
      );
      Get.offAllNamed('/permission');
    }
  }

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration.zero, _checkPermissionsAndNavigate);

    return Scaffold(
      backgroundColor: Colors.teal.shade900,
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}
