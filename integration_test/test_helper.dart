import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:detach/services/theme_service.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:detach/services/permission_service.dart';
import 'package:detach/services/platform_service.dart';
import 'package:detach/services/app_count_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:detach/firebase_options.dart';
import 'package:flutter/services.dart';

void mockPermissionChannel({bool hasPermissions = false}) {
  const channel = MethodChannel('com.detach.app/permissions');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'checkUsagePermission':
      case 'checkOverlayPermission':
      case 'checkBatteryOptimization':
      case 'openUsageSettings':
      case 'openOverlaySettings':
      case 'openBatterySettings':
        return hasPermissions;
      default:
        return null;
    }
  });
}

void mockPlatformChannel() {
  const channel = MethodChannel('com.detach.app/platform');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'updateStatusBar':
        return true;
      case 'getInstalledApps':
        return [
          {'packageName': 'com.test.app1', 'appName': 'App Tester'},
          {'packageName': 'com.test.app2', 'appName': 'Test App 2'}
        ];
      case 'isAppLocked':
        return false;
      case 'lockApp':
      case 'unlockApp':
        return true;
      default:
        return null;
    }
  });
}

Future<void> setupTestApp() async {
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Mock platform channels
  mockPermissionChannel(hasPermissions: false);
  mockPlatformChannel();

  // Initialize services
  Get.put(ThemeService());
  Get.put(AnalyticsService());
  Get.put(PlatformService());
  Get.put(AppCountService());
  Get.put(PermissionService());
}

/// Initialize all required services for testing
Future<void> initializeTestServices() async {
  // Mock permission method channel
  mockPermissionChannel();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize services
  Get.put(ThemeService());
  Get.put(AnalyticsService());
}

/// Helper to verify text is visible
Future<void> expectTextToBeVisible(WidgetTester tester, String text) async {
  expect(find.text(text), findsOneWidget);
  await tester.pumpAndSettle();
}

/// Helper to tap a button by text
Future<void> tapButton(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Helper to verify widget exists
bool widgetExists(WidgetTester tester, Finder finder) {
  return finder.evaluate().isNotEmpty;
}

/// Helper to tap a widget
Future<void> tapWidget(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Helper to scroll until widget is visible
Future<void> scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    500.0,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Helper to generate test report data
void reportTestStep(String description, String result) {
  print('TEST STEP: $description');
  print('RESULT: $result');
}
