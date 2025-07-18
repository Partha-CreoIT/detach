import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InfoBottomSheet extends StatelessWidget {
  const InfoBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'How Detach Works',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),

          // Simple steps
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSimpleStep(
                  context,
                  number: 1,
                  text:
                      'Pick your addictive apps (we know you\'ll try to open them 😅)',
                  icon: Icons.apps_rounded,
                ),

                const SizedBox(height: 16),

                _buildSimpleStep(
                  context,
                  number: 2,
                  text: 'Detach tracks how many times you attempt to open them',
                  icon: Icons.track_changes_rounded,
                ),

                const SizedBox(height: 16),

                _buildSimpleStep(
                  context,
                  number: 3,
                  text: 'Shows you: "You tried X times today" (reality check!)',
                  icon: Icons.psychology_rounded,
                ),

                const SizedBox(height: 16),

                _buildSimpleStep(
                  context,
                  number: 4,
                  text: 'If you really need it, set a timer (0-30 mins)',
                  icon: Icons.timer_rounded,
                ),

                const SizedBox(height: 16),

                _buildSimpleStep(
                  context,
                  number: 5,
                  text:
                      'Timer hits zero? App closes automatically. No excuses!',
                  icon: Icons.close_rounded,
                ),

                const SizedBox(height: 24),

                // Quick tip
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Start with 15 mins, then level up! Your future self will thank you ✨',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStep(
    BuildContext context, {
    required int number,
    required String text,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// Extension method to show the bottom sheet
extension InfoBottomSheetExtension on BuildContext {
  void showInfoBottomSheet() {
    showModalBottomSheet(
      context: this,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const InfoBottomSheet(),
    );
  }
}
