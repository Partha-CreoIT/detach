import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:detach/services/database_service.dart';
import 'package:detach/services/analytics_service.dart';

class StatisticsController extends GetxController {
  final DatabaseService _databaseService = DatabaseService();

  // Reactive variables
  final RxBool isLoading = true.obs;
  final RxString selectedPeriod = 'week'.obs;
  final RxList<Map<String, dynamic>> weeklyStats = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> topAppsByUsage = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> topPausedApps = <Map<String, dynamic>>[].obs;
  final RxMap<String, dynamic> overallStats = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> weeklyUsageData = <Map<String, dynamic>>[].obs;

  // Date range
  final Rx<DateTime> startDate = DateTime.now().subtract(const Duration(days: 7)).obs;
  final Rx<DateTime> endDate = DateTime.now().obs;

  // Reactive percentages for time distribution
  final RxDouble screenTimePercentage = 0.0.obs;
  final RxDouble pauseTimePercentage = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    _logScreenView();
    _loadStatistics();
  }

  Future<void> _logScreenView() async {
    await AnalyticsService.to.logScreenView('statistics_page');
  }

  Future<void> _loadStatistics() async {
    try {
      isLoading.value = true;

      // Check and clear old weekly data
      await _databaseService.checkAndClearOldWeeklyData();

      // Load locked apps daily stats
      await _loadLockedAppsDailyStats();

      // Load locked apps weekly stats
      await _loadLockedAppsWeeklyStats();

      // Load weekly usage data for charts
      await _loadWeeklyUsageData();

      // Load overall stats
      await _loadOverallStats();
    } catch (e) {
      print('Error loading statistics: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadLockedAppsDailyStats() async {
    // Debug: Check what's in the database
    await _databaseService.debugGetAllLockedApps();

    final stats = await _databaseService.getLockedAppsDailyStats();
    print('DEBUG: getLockedAppsDailyStats returned ${stats.length} apps');
    for (final app in stats) {
      print(
          '  - ${app['app_name']}: time_used=${app['time_used']}, total_locked_time=${app['total_locked_time']}');
    }
    topAppsByUsage.assignAll(stats);
  }

  Future<void> _loadLockedAppsWeeklyStats() async {
    final stats = await _databaseService.getLockedAppsWeeklyStats();
    topPausedApps.assignAll(stats);
  }

  Future<void> _loadWeeklyUsageData() async {
    final data = await _databaseService.getCurrentWeekUsageData();
    weeklyUsageData.assignAll(data);
    print('DEBUG: Loaded weekly usage data: ${data.length} days');
  }

  Future<void> _loadWeeklyStats() async {
    final stats = await _databaseService.getWeeklyStats(startDate.value);
    weeklyStats.assignAll(stats);
  }

  Future<void> _loadTopAppsByUsage() async {
    final apps = await _databaseService.getTopAppsByUsage(
      startDate: startDate.value,
      endDate: endDate.value,
      limit: 10,
    );
    topAppsByUsage.assignAll(apps);
  }

  Future<void> _loadTopPausedApps() async {
    final apps = await _databaseService.getTopPausedApps(
      startDate: startDate.value,
      endDate: endDate.value,
      limit: 10,
    );
    topPausedApps.assignAll(apps);
  }

  Future<void> _loadOverallStats() async {
    // Get locked apps daily stats for overall statistics
    final dailyStats = await _databaseService.getLockedAppsDailyStats();

    // Calculate totals from locked apps (show all locked apps, even if not used yet)
    int totalTimeUsed = 0;
    int totalApps = dailyStats.length; // Count all locked apps

    print('DEBUG: _loadOverallStats - Found ${dailyStats.length} apps');
    for (final app in dailyStats) {
      final timeUsed = (app['time_used'] ?? 0) as int;
      final appName = app['app_name'] ?? 'Unknown';
      final packageName = app['package_name'] ?? 'Unknown';
      print('DEBUG: _loadOverallStats - $appName ($packageName): time_used=$timeUsed seconds');
      totalTimeUsed += timeUsed;
    }
    print('DEBUG: _loadOverallStats - Total time used: $totalTimeUsed seconds');

    // Calculate total sessions
    int totalSessions = 0;
    for (final app in dailyStats) {
      totalSessions += (app['total_sessions'] ?? 0) as int;
    }

    final stats = {
      'total_screen_time_seconds': totalTimeUsed,
      'total_pause_time_seconds': 0, // Will be updated when pause tracking is implemented
      'unique_apps_used': totalApps,
      'unique_apps_paused': 0, // Will be updated when pause tracking is implemented
      'total_time_limit': 0, // Not using daily limits for now
      'remaining_time': 0, // Will be calculated per app
      'total_sessions': totalSessions,
    };

    overallStats.assignAll(stats);

    // Update reactive percentages
    _updatePercentages();
  }

  void _updatePercentages() {
    final totalScreenTime = overallStats['total_screen_time_seconds'] ?? 0;
    final totalPauseTime = overallStats['total_pause_time_seconds'] ?? 0;
    final total = totalScreenTime + totalPauseTime;

    if (total == 0) {
      screenTimePercentage.value = 0.0;
      pauseTimePercentage.value = 0.0;
    } else {
      screenTimePercentage.value = (totalScreenTime / total) * 100;
      pauseTimePercentage.value = (totalPauseTime / total) * 100;
    }
  }

  void changePeriod(String period) {
    selectedPeriod.value = period;

    final now = DateTime.now();
    switch (period) {
      case 'today':
        startDate.value = DateTime(now.year, now.month, now.day);
        endDate.value = now;
        break;
      case 'week':
        startDate.value = now.subtract(const Duration(days: 7));
        endDate.value = now;
        break;
      case 'month':
        startDate.value = DateTime(now.year, now.month - 1, now.day);
        endDate.value = now;
        break;
    }

    _loadStatistics();
  }

  String formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes}m ${remainingSeconds}s';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }

  String formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  // Refresh statistics
  Future<void> refreshStatistics() async {
    await _loadStatistics();
  }

  // Debug method to reset all time used (for testing)
  Future<void> debugResetAllTimeUsed() async {
    await _databaseService.debugResetAllTimeUsed();
    await _loadStatistics();
  }
}
