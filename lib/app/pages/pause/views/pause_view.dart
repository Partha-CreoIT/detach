import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:figma_squircle/figma_squircle.dart';
import '../controllers/pause_controller.dart';
import 'widgets/timer_view.dart';
import 'package:detach/services/theme_service.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PauseView extends GetView<PauseController> {
  const PauseView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.showTimer.value) {
        return const TimerView();
      }
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) {
            controller.closeApp();
          }
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: Theme.of(context).brightness == Brightness.dark
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
            child: Stack(
              children: [
                // Message Text
                Obx(
                  () => !controller.showButtons.value
                      ? Center(
                          child: Text(
                            "It's time to take a deep\nbreath...",
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
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
                        duration:
                            const Duration(seconds: 6), // Slower animation
                        curve: Curves.easeInOut,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                            colors: [
                              Color(0xFF6B75F2),
                              Color(0xFF8B5CF6),
                            ],
                            stops: [0.0, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Buttons and Counter
                Obx(
                  () => controller.showButtons.value
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Spacer(),
                              Text(
                                controller.attemptsToday.value.toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 120,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Obx(
                                () => Text(
                                  'attempts to open ${controller.displayAppName.isNotEmpty ? controller.displayAppName : (controller.lockedPackageName ?? "App")} within the\nlast 24 hours.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: controller.blockApp,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: const SmoothRectangleBorder(
                                    borderRadius: SmoothBorderRadius.all(
                                      SmoothRadius(
                                        cornerRadius: 8,
                                        cornerSmoothing: 1,
                                      ),
                                    ),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: Text(
                                  "I don't want to open ${controller.displayAppName}",
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                  onPressed: controller.continueApp,
                                  style: FilledButton.styleFrom(
                                    minimumSize:
                                        const Size(double.infinity, 44),
                                    shape: const SmoothRectangleBorder(
                                      borderRadius: SmoothBorderRadius.all(
                                        SmoothRadius(
                                          cornerRadius: 8,
                                          cornerSmoothing: 1,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: Text(
                                    'Continue on ${controller.displayAppName}',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )),
                              const SizedBox(height: 32),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // Timer is now handled by Android service, so no need to display countdown here
              ],
            ),
          ),
        ),
      );
    });
  }
}
