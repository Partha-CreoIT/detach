import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/permission_controller.dart';
import 'widgets/permission_battery_view.dart';
import 'widgets/permission_overlay_view.dart';
import 'widgets/permission_usage_view.dart';
import 'package:detach/app/routes/app_routes.dart';
import 'package:detach/services/theme_service.dart';
import 'package:flutter/services.dart';

class PermissionView extends GetView<PermissionController> {
  const PermissionView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Permissions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await controller.setBypassPermissions();
            Get.offAllNamed(AppRoutes.home);
          },
        ),
      ),
      body: SafeArea(
        child: PageView(
          controller: controller.pageController,
          physics: const NeverScrollableScrollPhysics(), // Disable swiping
          children: const [
            PermissionUsageView(),
            PermissionOverlayView(),
            PermissionBatteryView(),
          ],
        ),
      ),
    );
  }
}
