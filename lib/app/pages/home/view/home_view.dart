import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/home_controller.dart';
import 'widgets/overview_page.dart';
import 'widgets/settings_page.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [const OverviewPage(), const SettingsPage()];

    return Scaffold(
      body: Obx(() => pages[controller.tabIndex.value]),
      bottomNavigationBar: Obx(
        () => NavigationBar(
          selectedIndex: controller.tabIndex.value,
          onDestinationSelected: controller.changeTabIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
