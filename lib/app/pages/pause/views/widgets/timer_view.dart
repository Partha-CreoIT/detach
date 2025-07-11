import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/pause_controller.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:detach/services/platform_service.dart';

class TimerView extends GetView<PauseController> {
  const TimerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const Text(
                'Select allowed time',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'I commit to stop after this',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              Obx(
                () => GlowingTimeSlider(
                  value: controller.selectedMinutes.value,
                  onChanged: (v) => controller.selectedMinutes.value = v,
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B75F2),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      controller.startCountdown();
                      Get.back();
                    },
                    child: Text(
                      'Start Timer And Open ${controller.displayAppName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
}

class GlowingTimeSlider extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const GlowingTimeSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<GlowingTimeSlider> createState() => _GlowingTimeSliderState();
}

class _GlowingTimeSliderState extends State<GlowingTimeSlider> {
  late int _value;
  final _sliderKey = GlobalKey();

  @override
  void initState() {
    _value = widget.value;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant GlowingTimeSlider oldWidget) {
    if (widget.value != oldWidget.value) {
      setState(() {
        _value = widget.value;
      });
    }
    super.didUpdateWidget(oldWidget);
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
      int minutes = (pct * 30).round().clamp(0, 30);
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
        width: 340,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              painter: _GlowingTimePainter(_value / 30),
              size: const Size(340, 200),
            ),
            Positioned(
              bottom: 40,
              child: Text(
                '${_value}m',
                style: const TextStyle(
                  color: Color(0xFF6B75F2),
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowingTimePainter extends CustomPainter {
  final double progress;

  _GlowingTimePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = min(size.width / 2, size.height);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final backgroundPaint =
        Paint()
          ..color = Colors.grey.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24
          ..strokeCap = StrokeCap.round;

    final progressPaint =
        Paint()
          ..color = const Color(0xFF6B75F2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 24),
      pi,
      pi,
      false,
      backgroundPaint,
    );

    double sweepAngle = pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 24),
      pi,
      sweepAngle,
      false,
      progressPaint,
    );

    final dotAngle = pi + sweepAngle;
    final dotRadius = radius - 24;
    final dotOffset = Offset(
      center.dx + dotRadius * cos(dotAngle),
      center.dy + dotRadius * sin(dotAngle),
    );

    // Draw dot with reduced size
    canvas.drawCircle(dotOffset, 8, progressPaint);
    canvas.drawCircle(dotOffset, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
