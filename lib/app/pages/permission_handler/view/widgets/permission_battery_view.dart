import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/app/pages/permission_handler/controller/permission_controller.dart';
import 'package:google_fonts/google_fonts.dart';

class PermissionBatteryView extends GetView<PermissionController> {
  const PermissionBatteryView({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.battery_charging_full,
                    size: 48,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                'Battery Optimization',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'To work properly in the background, Detach needs to be excluded from battery optimization.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
          const SizedBox(height: 24),
          // Buttons
          SizedBox(
            width: double.maxFinite,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.battery_charging_full),
              label: Text(
                'Disable Battery Optimization',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () async {
                await controller.openBatteryOptimizationSettings();
                // Reset permission check so it will re-check when user returns
                controller.resetPermissionCheck();
              },
              style: FilledButton.styleFrom(
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
