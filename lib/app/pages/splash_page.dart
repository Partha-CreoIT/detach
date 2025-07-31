import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/app/routes/app_routes.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:detach/services/permission_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:detach/services/theme_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _logoController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _logoOpacityAnimation;

  @override
  void initState() {
    super.initState();

    // Main animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Main animations
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    // Logo animations
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));

    _logoRotationAnimation = Tween<double>(
      begin: -0.5,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack));

    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));

    // Start animations
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _logoController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
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
    // Don't redirect if we're already on the pause page
    if (Get.currentRoute.startsWith(AppRoutes.pause)) {
      return;
    }
    final permissionService = PermissionService();
    // Add delays to ensure proper permission checking
    await Future.delayed(const Duration(milliseconds: 500));
    final hasUsage = await permissionService.hasUsagePermission();

    final hasOverlay = await permissionService.hasOverlayPermission();

    final hasBattery = await permissionService.hasBatteryOptimizationIgnored();

    // Log permission status
    if (hasUsage) await AnalyticsService.to.logPermissionGranted('usage_stats');
    if (hasOverlay) await AnalyticsService.to.logPermissionGranted('overlay');
    if (hasBattery) await AnalyticsService.to.logPermissionGranted('battery_optimization');
    if (hasUsage && hasOverlay && hasBattery) {
      await AnalyticsService.to.logFeatureUsage('all_permissions_granted');
      Get.offAllNamed(AppRoutes.mainNavigation); // Navigate to main navigation
    } else {
      await AnalyticsService.to.logFeatureUsage('permissions_required');
      Get.offAllNamed(AppRoutes.permission);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_controller, _logoController]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [
                            const Color(0xFF1A1A1A),
                            const Color(0xFF2A2A2A),
                            const Color(0xFF1A1A1A),
                          ]
                        : [
                            const Color(0xFFFAFBFF),
                            const Color(0xFFF1F5F9),
                            const Color(0xFFFAFBFF),
                          ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 32),
                      Text(
                        "DETACH",
                        style: GoogleFonts.inter(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Break free from digital addiction",
                        style: GoogleFonts.inter(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : const Color(0xFF64748B),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
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
