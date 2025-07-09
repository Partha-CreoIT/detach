import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/app/pages/permission_handler/controller/permission_controller.dart';

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
            children: const [
              Text(
                'Battery Optimization',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Detach needs to be excluded from battery optimization so it can work reliably in the background. '
                'Please grant this permission in the settings.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => controller.openBatteryOptimizationSettings(),
              child: const Text('Grant battery permission'),
            ),
          ),
        ],
      ),
    );
  }
}
