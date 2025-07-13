import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:detach/services/permission_service.dart';
import 'package:detach/app/routes/app_routes.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      _navigateToProfile();
    });
  }

  void _navigateToProfile() async {
    // Log app launch
    await AnalyticsService.to.logAppLaunch();
    await AnalyticsService.to.logScreenView('splash');

    // Check permissions and navigate accordingly
    await _checkPermissionsAndNavigate();
  }

  Future<void> _checkPermissionsAndNavigate() async {
    debugPrint('SplashPage: Checking permissions...');

    // Don't redirect if we're already on the pause page
    if (Get.currentRoute.startsWith(AppRoutes.pause)) {
      debugPrint(
        'SplashPage: Already on pause page, skipping permission check',
      );
      return;
    }

    final permissionService = PermissionService();

    // Add delays to ensure proper permission checking
    await Future.delayed(const Duration(milliseconds: 500));

    final hasUsage = await permissionService.hasUsagePermission();
    debugPrint('SplashPage: Usage permission: $hasUsage');

    final hasOverlay = await permissionService.hasOverlayPermission();
    debugPrint('SplashPage: Overlay permission: $hasOverlay');

    final hasBattery = await permissionService.hasBatteryOptimizationIgnored();
    debugPrint('SplashPage: Battery optimization: $hasBattery');

    debugPrint(
      'SplashPage: Permissions check - Usage: $hasUsage, Overlay: $hasOverlay, Battery: $hasBattery',
    );

    // Log permission status
    if (hasUsage) await AnalyticsService.to.logPermissionGranted('usage_stats');

    if (hasOverlay) await AnalyticsService.to.logPermissionGranted('overlay');
    if (hasBattery)
      await AnalyticsService.to.logPermissionGranted('battery_optimization');

    if (hasUsage && hasOverlay && hasBattery) {
      debugPrint('SplashPage: All permissions granted, navigating to home');
      await AnalyticsService.to.logFeatureUsage('all_permissions_granted');
      Get.offAllNamed('${AppRoutes.home}?tab=0'); // tab=0 for overview page
    } else {
      debugPrint(
        'SplashPage: Missing permissions, navigating to permission page',
      );
      await AnalyticsService.to.logFeatureUsage('permissions_required');
      Get.offAllNamed(AppRoutes.permission);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.hourglass_empty_rounded,
                        color: Colors.white,
                        size: 80,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "DETACH",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace', // modern feel
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Take a break from digital life",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
