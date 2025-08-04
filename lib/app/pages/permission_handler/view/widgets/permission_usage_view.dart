import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/app/pages/permission_handler/controller/permission_controller.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class PermissionUsageView extends GetView<PermissionController> {
  const PermissionUsageView({super.key});

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
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.data_usage,
                    size: 48,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'App Usage Permission',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Detach requires permission to detect which app is currently in use so it can help you focus.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Lottie.asset(
                  'assets/app_usage.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.maxFinite,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.visibility),
              onPressed: () async {
                await controller.openUsageSettings();
                // Reset permission check so it will re-check when user returns
                controller.resetPermissionCheck();
              },
              style: FilledButton.styleFrom(
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 16, cornerSmoothing: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              label: Text(
                "Grant Usage Permission",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
