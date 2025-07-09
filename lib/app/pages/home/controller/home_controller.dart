import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeController extends GetxController {
  final RxInt tabIndex = 0.obs;
  final RxInt limitedAppsCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadLimitedAppsCount();
  }

  Future<void> _loadLimitedAppsCount() async {
    final prefs = await SharedPreferences.getInstance();
    // The key must match the one used by the native code, which will be fixed next.
    final blockedApps = prefs.getStringList("blocked_apps");
    limitedAppsCount.value = blockedApps?.length ?? 0;
  }

  void changeTabIndex(int index) {
    tabIndex.value = index;
  }

  void goToAddApps() async {
    // Wait for the app list screen to return a result.
    final result = await Get.toNamed('/apps');
    // If it returns true, it means the list was changed, so we reload.
    if (result == true) {
      _loadLimitedAppsCount();
    }
  }
}
