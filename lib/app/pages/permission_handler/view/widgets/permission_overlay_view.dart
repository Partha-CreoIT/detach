import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/app/pages/permission_handler/controller/permission_controller.dart';
import 'package:figma_squircle/figma_squircle.dart';

class PermissionOverlayView extends GetView<PermissionController> {
  const PermissionOverlayView({super.key});
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
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.layers,
                    size: 48,
                    color: Colors.purple,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Overlay Permission',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Detach needs permission to draw over other apps in order to display a blocking screen '
                'when you open a restricted app. Please enable this in settings.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '📋 Instructions:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Tap the button below\n'
                      '2. Toggle "Allow display over other apps"\n'
                      '3. Return to the app',
                      style: TextStyle(fontSize: 14, color: Colors.purple),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.maxFinite,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.layers),
              label: const Text(
                'Grant Overlay Permission',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              onPressed: () async {
                await controller.openOverlaySettings();
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
