import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:detach/main.dart' as app;
import 'package:detach/services/theme_service.dart';
import 'package:get/get.dart';
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Flow Tests', () {
    testWidgets('Complete app flow test with theme change and app enable',
        (tester) async {
      await setupTestApp();
      app.main();
      await tester.pumpAndSettle();

      // Wait for splash screen and verify analytics
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Verify we're on permission page
      expect(find.text('Configure Permissions'), findsOneWidget);
      expect(find.text('Permission Required'), findsOneWidget);

      // Click close button to bypass permissions and go to home
      await tapWidget(tester, find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify we're on home page
      expect(find.text('Overview'), findsOneWidget);

      // Test theme changes
      final themeButton = find.byType(PopupMenuButton<ThemeMode>);
      await tester.tap(themeButton);
      await tester.pumpAndSettle();

      // Test light theme
      await tester.tap(find.text('Light').hitTestable());
      await tester.pumpAndSettle();

      // Open menu again
      await tester.tap(themeButton);
      await tester.pumpAndSettle();

      // Test dark theme
      await tester.tap(find.text('Dark').hitTestable());
      await tester.pumpAndSettle();

      // Open menu again
      await tester.tap(themeButton);
      await tester.pumpAndSettle();

      // Test system theme
      await tester.tap(find.text('System').hitTestable());
      await tester.pumpAndSettle();

      // Test app list functionality
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'App Tester');
      await tester.pumpAndSettle();

      // Try to enable app without permissions
      final appSwitch = find.byType(Switch).first;
      await tester.tap(appSwitch);
      await tester.pumpAndSettle();

      // Verify permission bottom sheet appears
      expect(find.text('Permissions Required'), findsOneWidget);

      // Test cancel button
      await tapButton(tester, 'Cancel');
      await tester.pumpAndSettle();

      // Clear search and verify app list updates
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      // Test platform service
      final installedApps = find.text('App Tester');
      expect(installedApps, findsOneWidget);

      // Test permission service methods
      mockPermissionChannel(hasPermissions: true);
      await tester.enterText(searchField, 'App Tester');
      await tester.pumpAndSettle();
      await tester.tap(appSwitch);
      await tester.pumpAndSettle();

      // Clear search to see selected apps section
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      // Verify app is selected
      expect(find.text('Selected Apps (1)'), findsOneWidget);

      // Test error handling in services
      mockPermissionChannel(hasPermissions: false);
      await tester.enterText(searchField, 'App Tester');
      await tester.pumpAndSettle();
      await tester.tap(appSwitch);
      await tester.pumpAndSettle();
      await tester.pump(
          const Duration(milliseconds: 500)); // Wait for bottom sheet animation

      // Verify error handling works
      expect(find.text('Permissions Required'), findsOneWidget);
    });
  });
}
