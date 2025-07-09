import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/app/pages/permission_handler/controller/permission_controller.dart';
import 'package:figma_squircle/figma_squircle.dart';

class PermissionAccessibilityView extends GetView<PermissionController> {
  const PermissionAccessibilityView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Accessibility Permission',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Detach needs Accessibility Service to detect when you switch between apps '
                'and to show its blocking screen when necessary. Please enable it in settings.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => controller.openAccessibilitySettings(),
              style: ElevatedButton.styleFrom(
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(cornerRadius: 16, cornerSmoothing: 1),
                  ),
                ),
              ),
              child: const Text('Grant accessibility permission'),
            ),
          ),
        ],
      ),
    );
  }
}
