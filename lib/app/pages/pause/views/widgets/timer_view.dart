import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/pause_controller.dart';
import 'dart:math';
import 'package:flutter/services.dart';

class TimerView extends GetView<PauseController> {
  const TimerView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Header Section
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B75F2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      Icons.timer_outlined,
                      color: Color(0xFF6B75F2),
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Choose wisely… \nor suffer distractions!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color:
                          Theme.of(context).textTheme.headlineMedium?.color ??
                              const Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80),
              // Timer Slider Section
              Material(
                color: Theme.of(context).cardColor,
                elevation: 4,
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(
                      cornerRadius: 32,
                      cornerSmoothing: 1,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Obx(
                        () => ModernTimeSlider(
                          value: controller.selectedMinutes.value,
                          onChanged: (v) =>
                              controller.selectedMinutes.value = v,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Time indicators positioned at arc endpoints
                      SizedBox(
                        height: 16,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 16,
                              child: Text(
                                '1m',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.4) ??
                                      const Color(0xFF1A1A1A).withOpacity(0.4),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 16,
                              child: Text(
                                '30m',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.4) ??
                                      const Color(0xFF1A1A1A).withOpacity(0.4),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Text(
                'After this, I swear I\'m done. (Seriously!)',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.6) ??
                      const Color(0xFF1A1A1A).withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // Start Button
              Container(
                width: double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B75F2), Color(0xFF8B5CF6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B75F2).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      controller.startCountdown();
                    },
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Start Timer And Open ${controller.displayAppName}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class ModernTimeSlider extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const ModernTimeSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });
  @override
  State<ModernTimeSlider> createState() => _ModernTimeSliderState();
}

class _ModernTimeSliderState extends State<ModernTimeSlider>
    with TickerProviderStateMixin {
  late int _value;
  final _sliderKey = GlobalKey();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  @override
  void initState() {
    _value = widget.value;
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ModernTimeSlider oldWidget) {
    if (widget.value != oldWidget.value) {
      setState(() {
        _value = widget.value;
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updatePosition(Offset localPos) {
    final box = _sliderKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final center = Offset(size.width / 2, size.height);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    double angle = atan2(dy, dx);
    if (angle < 0) angle += 2 * pi;
    if (angle >= pi && angle <= 2 * pi) {
      double pct = ((angle - pi) / pi);
      int minutes = (pct * 29 + 1).round().clamp(1, 30);
      if (minutes != _value) {
        HapticFeedback.mediumImpact();
        setState(() {
          _value = minutes;
        });
        widget.onChanged(_value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _sliderKey,
      onPanDown: (details) => _updatePosition(details.localPosition),
      onPanUpdate: (details) => _updatePosition(details.localPosition),
      child: SizedBox(
        width: 320,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background track
            CustomPaint(
              painter: _ModernTrackPainter(),
              size: const Size(320, 200),
            ),
            // Progress track
            CustomPaint(
              painter: _ModernProgressPainter(_value / 30),
              size: const Size(320, 200),
            ),
            // Timer display at the bottom of the slider area
            Positioned(
              bottom: 10,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6B75F2).withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${_value}',
                              style: const TextStyle(
                                color: Color(0xFF6B75F2),
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'minutes',
                              style: TextStyle(
                                color: Color(0xFF6B75F2),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Handle
            CustomPaint(
              painter: _ModernHandlePainter(_value / 30),
              size: const Size(320, 200),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernTrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = min(size.width / 2, size.height) - 20;
    final trackPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      trackPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ModernProgressPainter extends CustomPainter {
  final double progress;
  _ModernProgressPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = min(size.width / 2, size.height) - 20;
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6B75F2), Color(0xFF8B5CF6)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    double sweepAngle = pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ModernHandlePainter extends CustomPainter {
  final double progress;
  _ModernHandlePainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = min(size.width / 2, size.height) - 20;
    final handleAngle = pi + (pi * progress);
    final handleOffset = Offset(
      center.dx + radius * cos(handleAngle),
      center.dy + radius * sin(handleAngle),
    );
    // Outer glow
    final glowPaint = Paint()
      ..color = const Color(0xFF6B75F2).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(handleOffset, 16, glowPaint);
    // Main handle
    final handlePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF6B75F2), Color(0xFF8B5CF6)],
      ).createShader(Rect.fromCircle(center: handleOffset, radius: 12))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(handleOffset, 12, handlePaint);
    // Inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(handleOffset.dx - 3, handleOffset.dy - 3),
      4,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
