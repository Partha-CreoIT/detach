import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/app/pages/permission_handler/controller/permission_controller.dart';

class StepperIndicator extends GetView<PermissionController> {
  const StepperIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Progress text
          Obx(() {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Step ${controller.currentPage.value + 1} of 4: ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  _getStepTitle(controller.currentPage.value),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 16),
          // Stepper dots
          Obx(() {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Row(
                  children: [
                    _buildStepIndicator(index),
                    if (index < 3) _buildConnector(index),
                  ],
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int index) {
    final isCurrentStep = controller.currentPage.value == index;
    final isCompleted = _isStepCompleted(index);
    final isPastStep = controller.currentPage.value > index;

    return Builder(
      builder: (context) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? Colors.green
                : isPastStep
                    ? Theme.of(context).colorScheme.primary
                    : isCurrentStep
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.surfaceVariant,
            border: isCurrentStep && !isCompleted
                ? Border.all(
                    color: Theme.of(context).colorScheme.secondary,
                    width: 2,
                  )
                : null,
          ),
          child: Center(
            child: isCompleted
                ? TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.5 + (0.5 * value),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      );
                    },
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isCompleted || isPastStep
                          ? Theme.of(context).colorScheme.onPrimary
                          : isCurrentStep
                              ? Theme.of(context).colorScheme.onSecondary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildConnector(int index) {
    final isCompleted = _isStepCompleted(index);

    return Builder(
      builder: (context) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 40,
          height: 2,
          color: isCompleted
              ? Colors.green
              : Theme.of(context).colorScheme.surfaceVariant,
        );
      },
    );
  }

  bool _isStepCompleted(int index) {
    switch (index) {
      case 0:
        return controller.hasUsagePermission.value;
      case 1:
        return controller.hasOverlayPermission.value;
      case 2:
        return controller.hasBatteryPermission.value;
      case 3:
        return false; // The last step is never "completed" as it's the final page
      default:
        return false;
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Usage Permission';
      case 1:
        return 'Overlay Permission';
      case 2:
        return 'Battery Permission';
      case 3:
        return 'How to Use';
      default:
        return '';
    }
  }
}
