import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wave/wave.dart';
import 'package:wave/config.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'pause_controller.dart';
import 'package:detach/services/app_count_service.dart';
import 'package:detach/services/platform_service.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:detach/app/routes/app_routes.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/physics.dart';

class PauseView extends StatefulWidget {
  const PauseView({super.key});

  @override
  State<PauseView> createState() => _PauseViewState();
}

class _PauseViewState extends State<PauseView>
    with SingleTickerProviderStateMixin {
  final PauseController controller = Get.put(PauseController());
  bool showTimer = false;
  bool showCountdown = false;
  static const int maxMinutes = 30;
  int selectedMinutes = 5;
  int elapsedSeconds = 0;
  int countdownSeconds = 0;
  Timer? timer;
  late AnimationController _controller;
  late Animation<double> _progressAnim;
  String appName = "Google Docs";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(minutes: maxMinutes),
    );
    _progressAnim = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
  }

  void startCountdown() {
    countdownSeconds = selectedMinutes * 60;
    elapsedSeconds = 0;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        elapsedSeconds++;
        if (elapsedSeconds % 60 == 0) {
          HapticFeedback.mediumImpact();
        }
        if (elapsedSeconds >= countdownSeconds) {
          timer?.cancel();
        }
      });
      _controller.value = elapsedSeconds / countdownSeconds;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String get timeString {
    final remaining = countdownSeconds - elapsedSeconds;
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (showTimer) {
      // Timer/slider view
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child:
                !showCountdown
                    ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        Text(
                          'Select allowed time',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),
                        HalfCircularSlider(
                          min: 1,
                          max: maxMinutes,
                          value: selectedMinutes,
                          onChanged: (v) {
                            setState(() {
                              selectedMinutes = v;
                            });
                          },
                          size: 380, // even larger
                          thickness: 56, // much thicker
                          progressColor: const Color(0xFF6B75F2),
                          trackColor: const Color(0xFFE0E0E0),
                          thumbColor: Colors.transparent, // no thumb
                        ),
                        const SizedBox(height: 24),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            "Use only this much time, not more than that!",
                            key: ValueKey('slider_${selectedMinutes}_msg'),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
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
                                setState(() {
                                  showCountdown = true;
                                  _controller.duration = Duration(
                                    minutes: selectedMinutes,
                                  );
                                  _controller.value = 0;
                                });
                                startCountdown();
                              },
                              child: Text(
                                'Start Timer',
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
                    )
                    : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        SizedBox(
                          width: 260,
                          height: 140,
                          child: CustomPaint(
                            painter: HalfCircleTimerPainter(
                              progress: _progressAnim.value,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    timeString,
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Time left',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            "Stay focused!",
                            key: ValueKey(countdownSeconds - elapsedSeconds),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
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
                              onPressed:
                                  (elapsedSeconds >= countdownSeconds)
                                      ? () async {
                                        debugPrint('Open $appName pressed');
                                        // await PlatformService.openApp('com.google.android.apps.docs.editors.docs');
                                      }
                                      : null,
                              child: Text(
                                'Open $appName',
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
    // Original pause view
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Obx(
              () =>
                  !controller.showButtons.value
                      ? const Center(
                        child: Text(
                          "It’s time to take a breath",
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
            AnimatedBuilder(
              animation: controller.waterAnimation,
              builder: (context, child) {
                if (controller.showButtons.value) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height:
                      MediaQuery.of(context).size.height *
                      controller.waterAnimation.value,
                  child: WaveWidget(
                    config: CustomConfig(
                      gradients: [
                        [Colors.blue.shade300, Colors.blue.shade200],
                        [Colors.blue.shade200, Colors.blue.shade100],
                      ],
                      durations: [3500, 19440],
                      heightPercentages: [0.25, 0.28],
                      blur: const MaskFilter.blur(BlurStyle.solid, 1),
                      gradientBegin: Alignment.bottomLeft,
                      gradientEnd: Alignment.topRight,
                    ),
                    size: const Size(double.infinity, double.infinity),
                    waveAmplitude: 0,
                  ),
                );
              },
            ),
            Obx(
              () =>
                  controller.showButtons.value && !controller.timerStarted.value
                      ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(),
                            Text(
                              controller.attemptsToday.value.toString(),
                              style: const TextStyle(
                                fontSize: 120,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Obx(
                              () => Text(
                                'attempts to open ${controller.appName.value.isNotEmpty ? controller.appName.value : (controller.lockedPackageName ?? "App")} within the\nlast 24 hours.',
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
                              onPressed: () async {
                                if (controller.lockedPackageName != null) {
                                  await AppCountService.incrementAppCount(
                                    controller.lockedPackageName!,
                                  );
                                  // Permanently block this app
                                  await PlatformService.permanentlyBlockApp(
                                    controller.lockedPackageName!,
                                  );
                                }
                                // Go to home/launcher and finish PauseActivity
                                await MethodChannel(
                                  'com.detach.app/permissions',
                                ).invokeMethod('goToHomeAndFinish');
                              },
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
                              child: Obx(
                                () => Text(
                                  "I don't want to open ${controller.appName.value.isNotEmpty ? controller.appName.value : (controller.lockedPackageName ?? "App")}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () async {
                                AnalyticsService.to
                                    .logPauseSessionInterrupted();
                                if (controller.lockedPackageName != null) {
                                  await PlatformService.resetAppBlock(
                                    controller.lockedPackageName!,
                                  );
                                }
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  setState(() {
                                    showTimer = true;
                                    elapsedSeconds = 0;
                                    _controller.value = 0;
                                  });
                                  startCountdown();
                                });
                              },
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
                              child: Obx(
                                () => Text(
                                  'Continue on ${controller.appName.value.isNotEmpty ? controller.appName.value : (controller.lockedPackageName ?? "App")}',
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
            Obx(
              () =>
                  controller.timerStarted.value
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              controller.start.value.toString(),
                              style: const TextStyle(
                                fontSize: 120,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const Text(
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
  }
}

class HalfCircularSlider extends StatefulWidget {
  final int min;
  final int max;
  final int value;
  final ValueChanged<int> onChanged;
  final double thickness;
  final Color trackColor;
  final Color progressColor;
  final Color thumbColor;
  final double size;

  const HalfCircularSlider({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.thickness = 18,
    this.trackColor = const Color(0xFFE0E0E0),
    this.progressColor = const Color(0xFF6B75F2),
    this.thumbColor = Colors.white,
    this.size = 220,
  });

  @override
  State<HalfCircularSlider> createState() => _HalfCircularSliderState();
}

class _HalfCircularSliderState extends State<HalfCircularSlider>
    with SingleTickerProviderStateMixin {
  late double _angle;
  late int _value;
  late AnimationController _animController;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    _angle = _valueToAngle(_value);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = Tween<double>(begin: _angle, end: _angle).animate(_animController);
  }

  @override
  void didUpdateWidget(covariant HalfCircularSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _value) {
      _animateToValue(widget.value);
    }
  }

  void _animateToValue(int newValue) {
    final newAngle = _valueToAngle(newValue);
    _anim = Tween<double>(begin: _angle, end: newAngle).animate(_animController)
      ..addListener(() {
        setState(() {});
      });
    _animController.forward(from: 0);
    _angle = newAngle;
    _value = newValue;
  }

  double _valueToAngle(int value) {
    final percent = (value - widget.min) / (widget.max - widget.min);
    return pi * percent;
  }

  int _angleToValue(double angle) {
    final percent = (angle / pi).clamp(0.0, 1.0);
    return (widget.min + (widget.max - widget.min) * percent).round();
  }

  void _onPanUpdate(Offset localPos) {
    final center = Offset(
      widget.size / 2,
      widget.size / 2 + widget.thickness / 2,
    );
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    double angle = atan2(dy, dx);
    // Only allow bottom half (pi to 2pi)
    if (angle < 0) angle += 2 * pi;
    if (angle < pi || angle > 2 * pi) return;
    final sliderAngle = angle - pi;
    final value = _angleToValue(sliderAngle);
    if (value != _value) {
      HapticFeedback.selectionClick();
      setState(() {
        _value = value;
        _angle = sliderAngle;
      });
      widget.onChanged(_value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final angle = _animController.isAnimating ? _anim.value : _angle;
    final percent = (angle / pi).clamp(0.0, 1.0);
    return GestureDetector(
      onPanUpdate: (details) {
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset local = box.globalToLocal(details.globalPosition);
        _onPanUpdate(local);
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size / 2 + widget.thickness * 1.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(widget.size, widget.size / 2 + widget.thickness * 1.5),
              painter: _HalfCircleSliderPainter(
                percent: percent,
                thickness: widget.thickness,
                trackColor: widget.trackColor,
                progressColor: widget.progressColor,
              ),
            ),
            // Center value display
            Positioned.fill(
              child: Center(
                child: Text(
                  '${_value} min',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: widget.progressColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HalfCircleSliderPainter extends CustomPainter {
  final double percent;
  final double thickness;
  final Color trackColor;
  final Color progressColor;

  _HalfCircleSliderPainter({
    required this.percent,
    required this.thickness,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final arcPadding = thickness * 0.1;
    final rect = Rect.fromLTWH(
      arcPadding,
      arcPadding,
      size.width - arcPadding * 2.5,
      (size.height - arcPadding) * 2 - arcPadding,
    );
    final startAngle = pi;
    final sweepAngle = pi * percent;

    // Glow effect for the arc
    final glowPaint =
        Paint()
          ..color = progressColor.withOpacity(0.35)
          ..strokeWidth = thickness + 18
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18);

    // Draw glow behind progress
    if (percent > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
    }

    // Draw background
    final bgPaint =
        Paint()
          ..color = trackColor
          ..strokeWidth = thickness
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi, false, bgPaint);

    // Draw progress
    final fgPaint =
        Paint()
          ..color = progressColor
          ..strokeWidth = thickness
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    if (percent > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle, false, fgPaint);
    }

    // Draw glowing dot at the end of the arc
    if (percent > 0) {
      final radius = rect.width / 2;
      final dotAngle = startAngle + sweepAngle;
      final dotRadius = radius;
      final center = Offset(
        rect.left + rect.width / 2,
        rect.top + rect.height / 2,
      );
      final dotOffset = Offset(
        center.dx + dotRadius * cos(dotAngle),
        center.dy + dotRadius * sin(dotAngle),
      );

      final dotPaint =
          Paint()
            ..color = progressColor
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(dotOffset, thickness * 0.6, dotPaint);
      canvas.drawCircle(
        dotOffset,
        thickness * 0.35,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HalfCircleSliderPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.thickness != thickness ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

class HalfCircleTimerPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  HalfCircleTimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    final startAngle = pi;
    final sweepAngle = pi * progress;
    final backgroundPaint =
        Paint()
          ..color = Colors.grey.shade200
          ..strokeWidth = 18
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    final progressPaint =
        Paint()
          ..color = const Color(0xFF6B75F2)
          ..strokeWidth = 18
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    // Draw background
    canvas.drawArc(rect, pi, pi, false, backgroundPaint);
    // Draw progress
    if (progress > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HalfCircleTimerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
