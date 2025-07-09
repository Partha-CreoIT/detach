import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/app/pages/permission_handler/controller/permission_controller.dart';

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
            children: const [
              Text(
                'Permission Required',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Detach requires permission to detect which app is currently in use so it can help you focus. '
                'This permission is only used on your device and never leaves it.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => controller.openUsageSettings(),
              child: const Text('Grant permission'),
            ),
          ),
        ],
      ),
    );
  }
}
