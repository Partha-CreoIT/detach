import 'dart:async';
import 'package:detach/services/platform_service.dart';
import 'package:detach/services/app_count_service.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:wave/wave.dart';
import 'package:wave/config.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

class PausePage extends StatefulWidget {
  const PausePage({super.key});

  @override
  State<PausePage> createState() => _PausePageState();
}

class _PausePageState extends State<PausePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _waterController;
  late Animation<double> _waterAnimation;

  Timer? _timer;

  int _start = 60;
  int _attemptsToday = 0;
  String? _lockedPackageName;
  String _appName = "";
  List<AppInfo> _allApps = [];

  bool _showButtons = false;
  bool _timerStarted = false;

  @override
  void initState() {
    super.initState();

    _lockedPackageName = Get.parameters['package'];
    debugPrint('PausePage: Initialized with package: $_lockedPackageName');

    // Log analytics
    AnalyticsService.to.logScreenView('pause_page');
    if (_lockedPackageName != null) {
      AnalyticsService.to.logAppBlocked(_lockedPackageName!);
    }

    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _waterAnimation = Tween<double>(begin: 0.0, end: 1.45).animate(
      CurvedAnimation(parent: _waterController, curve: Curves.easeInOut),
    );

    _waterController.forward();

    _waterController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _waterController.reverse();
      }
      if (status == AnimationStatus.dismissed) {
        setState(() {
          _showButtons = true;
        });
      }
    });

    _initializeAppData();
  }

  Future<void> _initializeAppData() async {
    if (_lockedPackageName != null) {
      // Load all apps to get app names
      try {
        _allApps = await InstalledApps.getInstalledApps(true, true);
        _appName = AppCountService.getAppNameFromPackage(
          _lockedPackageName!,
          _allApps,
        );

        // Load the count for this specific app
        _attemptsToday = await AppCountService.getAppCount(_lockedPackageName!);

        setState(() {});
      } catch (e) {
        debugPrint('Error loading app data: $e');
        _appName = _lockedPackageName!;
      }
    }
  }

  void startTimer() {
    _timerStarted = true;

    // Log pause session started
    AnalyticsService.to.logPauseSession(_start);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_start == 0) {
        timer.cancel();

        // Log pause session completed
        AnalyticsService.to.logPauseSessionCompleted(60);

        // Close the pause activity first
        await PlatformService.closeBothApps();

        // Then launch the app after a short delay to avoid conflicts
        if (_lockedPackageName != null) {
          Future.delayed(const Duration(milliseconds: 500), () async {
            await PlatformService.launchApp(_lockedPackageName!);
          });
        }
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  @override
  void dispose() {
    _waterController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appName =
        _appName.isNotEmpty ? _appName : (_lockedPackageName ?? "App");

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            if (!_showButtons)
              const Center(
                child: Text(
                  "It’s time to take a breath",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            AnimatedBuilder(
              animation: _waterAnimation,
              builder: (context, child) {
                if (_showButtons) {
                  // remove water completely after animation
                  return const SizedBox.shrink();
                }
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height:
                      MediaQuery.of(context).size.height *
                      _waterAnimation.value,
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
            if (_showButtons && !_timerStarted)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Text(
                      _attemptsToday.toString(),
                      style: const TextStyle(
                        fontSize: 120,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'attempts to open $appName within the\nlast 24 hours.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        // Increment count for this specific app
                        if (_lockedPackageName != null) {
                          await AppCountService.incrementAppCount(
                            _lockedPackageName!,
                          );
                        }
                        // Close both apps
                        await PlatformService.closeBothApps();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6B75F2),
                        minimumSize: const Size(double.infinity, 56),
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 16, cornerSmoothing: 1),
                          ),
                        ),
                      ),
                      child: Text(
                        "I don't want to open $appName",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        // Log analytics for continue action
                        AnalyticsService.to.logPauseSessionInterrupted();

                        // Reset the permanent block so user can actually open the app
                        if (_lockedPackageName != null) {
                          await PlatformService.resetAppBlock(
                            _lockedPackageName!,
                          );
                        }

                        // Start timer instead of immediately launching app
                        setState(() {
                          startTimer();
                        });
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        foregroundColor: const Color(0xFF6B75F2),
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 16, cornerSmoothing: 1),
                          ),
                        ),
                      ),
                      child: Text('Continue on $appName'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            if (_timerStarted)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _start.toString(),
                      style: const TextStyle(
                        fontSize: 120,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const Text(
                      'seconds remaining',
                      style: TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
