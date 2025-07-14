import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:detach/main.dart';
import 'package:detach/services/theme_service.dart';
import 'package:detach/services/analytics_service.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:detach/firebase_options.dart';

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize GetX services
    Get.put(ThemeService());
    Get.put(AnalyticsService());
  });

  testWidgets('App Flow Test', (WidgetTester tester) async {
    // Start the app
    await tester.pumpWidget(const DetachApp());
    await tester.pumpAndSettle();

    // Check splash screen texts
    expect(find.text('DETACH'), findsOneWidget);
    expect(find.text('Take a break from digital life'), findsOneWidget);

    // Wait for splash animation and navigation
    await Future.delayed(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // We should be on either the permission screen or home screen
    // depending on permission status
    final hasPermissionScreen = find.text('Configure Permissions');
    final hasOverviewScreen = find.text('Overview');

    expect(
      hasPermissionScreen.evaluate().isNotEmpty ||
          hasOverviewScreen.evaluate().isNotEmpty,
      isTrue,
      reason: 'Should be on either permission screen or overview screen',
    );

    // If we're on the permission screen, verify the first permission view is shown
    if (hasPermissionScreen.evaluate().isNotEmpty) {
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    }
  });
}
