import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../home/bindings/home_binding.dart';
import '../../statistics/bindings/statistics_binding.dart';

class MainNavigationController extends GetxController {
  final RxInt currentIndex = 0.obs;
  final PageController pageController = PageController();

  @override
  void onInit() {
    super.onInit();
    // Initialize controllers for both pages
    HomeBinding().dependencies();
    StatisticsBinding().dependencies();
  }

  final List<Widget> pages = [
    // Home page will be loaded via GetView
    const SizedBox.shrink(),
    // Statistics page will be loaded via GetView
    const SizedBox.shrink(),
  ];

  void changePage(int index) {
    currentIndex.value = index;
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
