import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:figma_squircle/figma_squircle.dart';
import '../controllers/pause_controller.dart';
import 'widgets/timer_view.dart';

class PauseView extends GetView<PauseController> {
  const PauseView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.showTimer.value) {
        return const TimerView();
      }
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              // Message Text
              Obx(
                    () => !controller.showButtons.value
                    ? Center(
                  child: Text(
                    "It's time to take a breath",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
                    : const SizedBox.shrink(),
              ),

              // Animated Container
              AnimatedBuilder(
                animation: controller.waterAnimation,
                builder: (context, child) {
                  if (controller.showButtons.value) {
                    return const SizedBox.shrink();
                  }
                  final screenHeight = MediaQuery.of(context).size.height;
                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: screenHeight * controller.waterAnimation.value,
                    child: AnimatedContainer(
                      duration: const Duration(seconds: 5),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [
                            const Color(0xFF667eea), // Electric blue
                            const Color(0xFF764ba2), // Purple
                            const Color(0xFF00d4ff), // Cyan
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Buttons and Counter
              Obx(
                    () =>
                controller.showButtons.value &&
                    !controller.timerStarted.value
                    ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Text(
                        controller.attemptsToday.value.toString(),
                        style: TextStyle(
                          fontSize: 120,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                            () => Text(
                          'attempts to open ${controller.displayAppName.isNotEmpty ? controller.displayAppName : (controller.lockedPackageName ?? "App")} within the\nlast 24 hours.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: controller.blockApp,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6B75F2),
                          minimumSize: const Size(double.infinity, 56),
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(
                                cornerRadius: 16,
                                cornerSmoothing: 1,
                              ),
                            ),
                          ),
                        ),
                        child: Text(
                          "I don't want to open ${controller.displayAppName}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: controller.continueApp,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          foregroundColor: const Color(0xFF6B75F2),
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(
                                cornerRadius: 16,
                                cornerSmoothing: 1,
                              ),
                            ),
                          ),
                        ),
                        child: Text(
                          'Continue on ${controller.displayAppName}',
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                )
                    : const SizedBox.shrink(),
              ),

              // Timer
              Obx(
                    () => controller.timerStarted.value
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        controller.start.value.toString(),
                        style: TextStyle(
                          fontSize: 120,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'seconds remaining',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    });
  }
}

