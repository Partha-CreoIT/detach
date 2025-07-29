import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:figma_squircle/figma_squircle.dart';
import 'package:google_fonts/google_fonts.dart';

class HowToUseView extends StatefulWidget {
  const HowToUseView({super.key});

  @override
  State<HowToUseView> createState() => _HowToUseViewState();
}

class _HowToUseViewState extends State<HowToUseView> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Animated Icon
                  Center(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1200),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (0.2 * value),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.check_circle,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'You\'re All Set!',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Detach is now ready to help you stay focused. Here\'s how to use it:',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb,
                                color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'How to Use:',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionItem(
                          '1',
                          'Open any app you want to limit',
                          Icons.apps,
                        ),
                        const SizedBox(height: 8),
                        _buildInstructionItem(
                          '2',
                          'Tap the Detach floating button',
                          Icons.touch_app,
                        ),
                        const SizedBox(height: 8),
                        _buildInstructionItem(
                          '3',
                          'Set your focus timer and start',
                          Icons.timer,
                        ),
                        const SizedBox(height: 8),
                        _buildInstructionItem(
                          '4',
                          'Stay focused until the timer ends',
                          Icons.psychology,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    Get.offAllNamed('/home');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  label: Text(
                    "Continue",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
