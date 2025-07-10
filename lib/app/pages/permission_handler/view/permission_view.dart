import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/permission_controller.dart';
import 'widgets/permission_accessibility_view.dart';
import 'widgets/permission_battery_view.dart';
import 'widgets/permission_overlay_view.dart';
import 'widgets/permission_usage_view.dart';
import 'package:detach/app/routes/app_routes.dart';

class PermissionView extends GetView<PermissionController> {
  const PermissionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Permissions'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.offAllNamed(AppRoutes.home),
        ),
      ),
      body: SafeArea(
        child: PageView(
          controller: controller.pageController,
          physics: const NeverScrollableScrollPhysics(), // Disable swiping
          children: const [
            PermissionUsageView(),
            PermissionAccessibilityView(),
            PermissionOverlayView(),
            PermissionBatteryView(),
          ],
        ),
      ),
    );
  }
}
