import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/app_info.dart';
class AppCountService {
  static const String _countPrefix = 'app_count_';
  /// Get the count of "I don't want to open" clicks for a specific app
  static Future<int> getAppCount(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_countPrefix$packageName') ?? 0;
  }
  /// Increment the count for a specific app
  static Future<void> incrementAppCount(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = await getAppCount(packageName);
    await prefs.setInt('$_countPrefix$packageName', currentCount + 1);
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
