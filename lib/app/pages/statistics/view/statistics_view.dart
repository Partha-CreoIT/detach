import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:detach/services/theme_service.dart';
import '../controller/statistics_controller.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:detach/services/database_service.dart';

class StatisticsView extends GetView<StatisticsController> {
  const StatisticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Statistics',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Debug button to reset time used
          IconButton(
            onPressed: () => controller.debugResetAllTimeUsed(),
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Reset Time Used (Debug)',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshStatistics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall Screen Time Graph
                _buildOverallScreenTimeGraph(context),
                const SizedBox(height: 24),

                // Locked Apps List
                _buildLockedAppsList(context),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildOverallScreenTimeGraph(BuildContext context) {
    final stats = controller.overallStats;
    final totalTime = stats['total_screen_time_seconds'] ?? 0;
    final totalApps = stats['unique_apps_used'] ?? 0;
    final weeklyData = controller.weeklyUsageData;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Screen Time',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Weekly bar chart
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: weeklyData.isNotEmpty
                    ? weeklyData
                        .map((d) => (d['usage_seconds'] ?? 0) as int)
                        .reduce((a, b) => a > b ? a : b)
                        .toDouble()
                    : 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        // Always show day labels regardless of data
                        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(
                            days[value.toInt()],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${(value / 60).round()}m',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      width: 1,
                    ),
                    left: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 1,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                barGroups: List.generate(7, (index) {
                  final data = weeklyData.isNotEmpty && index < weeklyData.length
                      ? weeklyData[index]
                      : {'usage_seconds': 0};
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: (data['usage_seconds'] ?? 0).toDouble(),
                        color: Theme.of(context).colorScheme.primary,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Stats summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                'Total Time',
                controller.formatDuration(totalTime),
                Icons.access_time,
              ),
              _buildStatItem(
                context,
                'Locked Apps',
                '$totalApps',
                Icons.phone_android,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedAppsList(BuildContext context) {
    if (controller.topAppsByUsage.isEmpty) {
      return _buildEmptyState(context, 'No locked apps found');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Locked Apps',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.topAppsByUsage.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
            itemBuilder: (context, index) {
              final app = controller.topAppsByUsage[index];
              final appName = app['app_name'] ?? 'Unknown App';
              final timeUsed = app['time_used'] ?? 0;
              final totalSessions = app['total_sessions'] ?? 0;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: FutureBuilder<Widget>(
                  future: _getAppIcon(app['package_name'] ?? ''),
                  builder: (context, snapshot) {
                    return CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: snapshot.data ??
                          Icon(
                            Icons.phone_android,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    );
                  },
                ),
                title: Text(
                  appName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  controller.formatDuration(timeUsed),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                onTap: () => _showAppDetails(context, app),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAppDetails(BuildContext context, Map<String, dynamic> app) {
    final appName = app['app_name'] ?? 'Unknown App';
    final packageName = app['package_name'] ?? '';
    final timeUsed = app['time_used'] ?? 0;
    final totalSessions = app['total_sessions'] ?? 0;
    final averageSessionTime = app['average_session_time'] ?? 0;

    Get.bottomSheet(
      Container(
        height: Get.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Icon(
                          Icons.phone_android,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appName,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '${controller.formatDuration(timeUsed)} used',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Daily usage graph
                  Text(
                    'Daily Usage (Last 7 Days)',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 200,
                    child: _buildDailyUsageChart(context, packageName),
                  ),

                  const SizedBox(height: 24),

                  // Stats grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailStat(
                          context,
                          'Total Time',
                          controller.formatDuration(timeUsed),
                          Icons.access_time,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDetailStat(
                          context,
                          'Avg Session',
                          controller.formatDuration(averageSessionTime),
                          Icons.timer,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildDailyUsageChart(BuildContext context, String packageName) {
    // Get weekly usage data for this specific app
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAppWeeklyUsageData(packageName),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final dailyData = snapshot.data!;

        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: dailyData.isNotEmpty
                ? dailyData
                    .map((d) => (d['usage_seconds'] ?? 0) as int)
                    .reduce((a, b) => a > b ? a : b)
                    .toDouble()
                : 100.0,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    // Always show day labels regardless of data
                    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    if (value.toInt() >= 0 && value.toInt() < days.length) {
                      return Text(
                        days[value.toInt()],
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '${(value / 60).round()}m',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
                left: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              horizontalInterval: 1,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  strokeWidth: 1,
                );
              },
            ),
            barGroups: List.generate(7, (index) {
              final data = dailyData.isNotEmpty && index < dailyData.length
                  ? dailyData[index]
                  : {'usage_seconds': 0};
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: (data['usage_seconds'] ?? 0).toDouble(),
                    color: Theme.of(context).colorScheme.primary,
                    width: 20,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getAppWeeklyUsageData(String packageName) async {
    // This will use the database service to get weekly usage for this specific app
    final databaseService = DatabaseService();
    return await databaseService.getAppDailyUsage(packageName);
  }

  Widget _buildDetailStat(BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Get app icon for the given package name
  Future<Widget> _getAppIcon(String packageName) async {
    try {
      // Get all installed apps and find the matching one
      final apps = await InstalledApps.getInstalledApps(false, true);
      final matchingApps = apps.where((app) => app.packageName == packageName).toList();

      if (matchingApps.isNotEmpty && matchingApps.first.icon != null) {
        return Image.memory(
          matchingApps.first.icon!,
          width: 40,
          height: 40,
          errorBuilder: (context, error, stackTrace) {
            return _getFallbackIcon(packageName);
          },
        );
      } else {
        return _getFallbackIcon(packageName);
      }
    } catch (e) {
      return _getFallbackIcon(packageName);
    }
  }

  Widget _getFallbackIcon(String packageName) {
    // Fallback to package name based icons
    if (packageName.contains('instagram')) {
      return Icon(Icons.camera_alt, color: Colors.purple);
    } else if (packageName.contains('gmail')) {
      return Icon(Icons.email, color: Colors.red);
    } else if (packageName.contains('drive')) {
      return Icon(Icons.folder, color: Colors.blue);
    } else if (packageName.contains('whatsapp')) {
      return Icon(Icons.chat, color: Colors.green);
    } else if (packageName.contains('youtube')) {
      return Icon(Icons.play_circle, color: Colors.red);
    } else if (packageName.contains('facebook')) {
      return Icon(Icons.facebook, color: Colors.blue);
    } else if (packageName.contains('twitter')) {
      return Icon(Icons.flutter_dash, color: Colors.lightBlue);
    } else {
      return Icon(Icons.phone_android, color: Colors.grey);
    }
  }
}
