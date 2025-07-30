import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:detach/services/theme_service.dart';
import '../controller/statistics_controller.dart';
import 'package:fl_chart/fl_chart.dart';

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
            'Overall Screen Time',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          // Simple bar chart for overall usage
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: totalTime > 0 ? totalTime.toDouble() : 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          'Total',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        );
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
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: totalTime.toDouble(),
                        color: Theme.of(context).colorScheme.primary,
                        width: 60,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ],
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
                       child: snapshot.data ?? Icon(
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
    // Generate sample daily data (in real app, this would come from database)
    final dailyData = List.generate(7, (index) {
      final day = DateTime.now().subtract(Duration(days: 6 - index));
      return {
        'date': day,
        'usage': (index * 5 + 10) * 60, // Sample data in seconds
      };
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: dailyData.isNotEmpty 
            ? dailyData.map((d) => d['usage'] as int).reduce((a, b) => a > b ? a : b).toDouble()
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
                if (value.toInt() >= 0 && value.toInt() < dailyData.length) {
                  final day = dailyData[value.toInt()]['date'] as DateTime;
                  return Text(
                    '${day.day}/${day.month}',
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
        borderData: FlBorderData(show: false),
        barGroups: dailyData.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (data['usage'] as int).toDouble(),
                color: Theme.of(context).colorScheme.primary,
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
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
      // For now, return a simple icon based on package name
      // In a real app, you would use package_info_plus or similar to get actual app icons
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
    } catch (e) {
      return Icon(Icons.phone_android, color: Colors.grey);
    }
  }
}
