import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/app_info.dart';

class AppCountService {
  static const String _countPrefix = 'app_count_';
  static const String _timestampPrefix = 'app_count_timestamp_';
  static const int _resetIntervalHours = 24;

  /// Get the count of "I don't want to open" clicks for a specific app (within last 24 hours)
  static Future<int> getAppCount(String packageName) async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we need to reset based on timestamp
    await _checkAndResetIfNeeded(packageName);

    return prefs.getInt('$_countPrefix$packageName') ?? 0;
  }

  /// Increment the count for a specific app
  static Future<void> incrementAppCount(String packageName) async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we need to reset before incrementing
    await _checkAndResetIfNeeded(packageName);

    final currentCount = prefs.getInt('$_countPrefix$packageName') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

        await prefs.setInt('$_countPrefix$packageName', currentCount + 1);
    await prefs.setInt('$_timestampPrefix$packageName', now);
  }

  /// Check if 24 hours have passed and reset if needed
  static Future<void> _checkAndResetIfNeeded(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTimestamp = prefs.getInt('$_timestampPrefix$packageName');

    if (lastTimestamp != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final hoursPassed = (now - lastTimestamp) / (1000 * 60 * 60);

      if (hoursPassed >= _resetIntervalHours) {
        // Reset count and timestamp
        await prefs.remove('$_countPrefix$packageName');
        await prefs.remove('$_timestampPrefix$packageName');
      }
    }
  }

  /// Reset all app counts (for testing or manual reset)
  static Future<void> resetAllCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_countPrefix) || key.startsWith(_timestampPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// Get debug info for a specific app
  static Future<Map<String, dynamic>> getDebugInfo(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('$_countPrefix$packageName') ?? 0;
    final timestamp = prefs.getInt('$_timestampPrefix$packageName');

    String timeInfo = 'No timestamp';
    if (timestamp != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final hoursPassed = (now.millisecondsSinceEpoch - timestamp) / (1000 * 60 * 60);
      timeInfo = 'Last increment: $date (${hoursPassed.toStringAsFixed(2)} hours ago)';
    }

    return {
      'packageName': packageName,
      'count': count,
      'timestamp': timestamp,
      'timeInfo': timeInfo,
    };
  }

  /// Get app name from package name (fallback to package name if not found)
  static String getAppNameFromPackage(
    String packageName,
    List<AppInfo>? allApps,
  ) {
    if (allApps == null) return packageName;
    try {
      final app = allApps.firstWhere((app) => app.packageName == packageName);
      return app.name;
    } catch (e) {
      // If app not found, return package name as fallback
      return packageName;
    }
  }
}
