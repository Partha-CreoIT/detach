import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:figma_squircle/figma_squircle.dart';

class ThemeService extends GetxController {
  static ThemeService get to => Get.find();
  final RxBool isDarkMode = false.obs;
  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  // Light Theme Colors
  static const Color lightPrimary = Color(0xFF6366F1); // Indigo
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightSecondary = Color(0xFF8B5CF6); // Violet
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightTertiary = Color(0xFF06B6D4); // Cyan
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightBackground = Color(0xFFFAFBFF);
  static const Color lightOnBackground = Color(0xFF1E293B);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF1E293B);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightOnSurfaceVariant = Color(0xFF64748B);
  static const Color lightOutline = Color(0xFFCBD5E1);
  static const Color lightOutlineVariant = Color(0xFFE2E8F0);
  static const Color lightError = Color(0xFFEF4444);
  static const Color lightOnError = Color(0xFFFFFFFF);
  // Dark Theme Colors
  static const Color darkPrimary = Color(0xFF818CF8); // Lighter Indigo
  static const Color darkOnPrimary = Color(0xFF1E293B);
  static const Color darkSecondary = Color(0xFFA78BFA); // Lighter Violet
  static const Color darkOnSecondary = Color(0xFF1E293B);
  static const Color darkTertiary = Color(0xFF22D3EE); // Lighter Cyan
  static const Color darkOnTertiary = Color(0xFF1E293B);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkOnBackground = Color(0xFFF8FAFC);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkOnSurface = Color(0xFFF8FAFC);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkOnSurfaceVariant = Color(0xFFCBD5E1);
  static const Color darkOutline = Color(0xFF475569);
  static const Color darkOutlineVariant = Color(0xFF334155);
  static const Color darkError = Color(0xFFF87171);
  static const Color darkOnError = Color(0xFF1E293B);
  @override
  void onInit() {
    super.onInit();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString('themeMode') ?? 'system';
    switch (themeModeString) {
      case 'light':
        themeMode.value = ThemeMode.light;
        isDarkMode.value = false;
        break;
      case 'dark':
        themeMode.value = ThemeMode.dark;
        isDarkMode.value = true;
        break;
      case 'system':
      default:
        themeMode.value = ThemeMode.system;
        isDarkMode.value = false;
        break;
    }
    // Update status bar style after loading theme preference
    updateStatusBarStyle();
  }

  Future<void> toggleTheme() async {
    isDarkMode.value = !isDarkMode.value;
    themeMode.value = isDarkMode.value ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', isDarkMode.value ? 'dark' : 'light');
    // Update status bar style based on theme
    updateStatusBarStyle();
    Get.changeThemeMode(themeMode.value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    isDarkMode.value = mode == ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    String themeModeString;
    switch (mode) {
      case ThemeMode.light:
        themeModeString = 'light';
        break;
      case ThemeMode.dark:
        themeModeString = 'dark';
        break;
      case ThemeMode.system:
        themeModeString = 'system';
        break;
    }
    await prefs.setString('themeMode', themeModeString);
    // Update status bar style based on theme
    updateStatusBarStyle();
    Get.changeThemeMode(mode);
    // Force another update after theme change
    Future.delayed(const Duration(milliseconds: 100), () {
      updateStatusBarStyle();
    });
  }

  void updateStatusBarStyle() {
    // Simple approach - just use the isDarkMode value
    final statusBarIconBrightness =
        isDarkMode.value ? Brightness.light : Brightness.dark;

    // Force update the status bar style
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: statusBarIconBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        onPrimary: lightOnPrimary,
        secondary: lightSecondary,
        onSecondary: lightOnSecondary,
        tertiary: lightTertiary,
        onTertiary: lightOnTertiary,
        background: lightBackground,
        onBackground: lightOnBackground,
        surface: lightSurface,
        onSurface: lightOnSurface,
        surfaceVariant: lightSurfaceVariant,
        onSurfaceVariant: lightOnSurfaceVariant,
        outline: lightOutline,
        outlineVariant: lightOutlineVariant,
        error: lightError,
        onError: lightOnError,
      ),
      // Custom component themes
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 2,
        shadowColor: lightOutline.withValues(alpha: 0.1),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 16, cornerSmoothing: 1),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightOnSurface,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: lightPrimary.withValues(alpha: 0.1),
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(
              color: lightOnSurface,
            ); // Black for selected
          }
          return const IconThemeData(
            color: lightOnSurfaceVariant,
          ); // Grey for unselected
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: lightOnPrimary,
          elevation: 0,
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 16, cornerSmoothing: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimary,
          side: const BorderSide(color: lightPrimary),
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 16, cornerSmoothing: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return lightOnPrimary;
          }
          return lightOutline;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return lightPrimary;
          }
          return lightOutlineVariant;
        }),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        secondary: darkSecondary,
        onSecondary: darkOnSecondary,
        tertiary: darkTertiary,
        onTertiary: darkOnTertiary,
        background: darkBackground,
        onBackground: darkOnBackground,
        surface: darkSurface,
        onSurface: darkOnSurface,
        surfaceVariant: darkSurfaceVariant,
        onSurfaceVariant: darkOnSurfaceVariant,
        outline: darkOutline,
        outlineVariant: darkOutlineVariant,
        error: darkError,
        onError: darkOnError,
      ),
      // Custom component themes
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 2,
        shadowColor: darkOutline.withValues(alpha: 0.1),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: 16, cornerSmoothing: 1),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkOnSurface,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: darkPrimary.withValues(alpha: 0.1),
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(
              color: darkOnSurface,
            ); // White for selected
          }
          return const IconThemeData(
            color: darkOnSurfaceVariant,
          ); // Grey for unselected
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkOnPrimary,
          elevation: 0,
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 16, cornerSmoothing: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          side: const BorderSide(color: darkPrimary),
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: 16, cornerSmoothing: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return darkOnPrimary;
          }
          return darkOutline;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return darkPrimary;
          }
          return darkOutlineVariant;
        }),
      ),
    );
  }
}
