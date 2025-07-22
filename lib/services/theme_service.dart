import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeService extends GetxService {
  static final Rx<ThemeMode> _themeMode = ThemeMode.system.obs;
  static final RxBool _isDarkMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Listen for system theme changes
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        () {
      if (_themeMode.value == ThemeMode.system) {
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        _isDarkMode.value = brightness == Brightness.dark;
        updateStatusBarStyle();
      }
    };

    // Initialize with current system theme
    if (_themeMode.value == ThemeMode.system) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _isDarkMode.value = brightness == Brightness.dark;
    }
  }

  // Font configurations
  static const String _sansSerifFont = 'Inter';
  static const String _serifFont = 'Playfair Display';

  // Getter for theme mode
  Rx<ThemeMode> get themeMode => _themeMode;

  // Getter for dark mode status
  RxBool get isDarkMode => _isDarkMode;

  // Light theme with custom fonts
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6B75F2),
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.interTextTheme().copyWith(
      // Headlines
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1A1A1A),
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1A1A1A),
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1A1A1A),
      ),
      // Body text
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: const Color(0xFF1A1A1A),
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: const Color(0xFF1A1A1A),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: const Color(0xFF666666),
      ),
      // Title text
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1A1A1A),
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF1A1A1A),
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF1A1A1A),
      ),
      // Serif font for special text
      labelLarge: GoogleFonts.playfairDisplay(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF1A1A1A),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1A1A1A),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6B75F2),
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6B75F2), width: 2),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xFF666666),
      ),
    ),
  );

  // Dark theme with custom fonts
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6B75F2),
      brightness: Brightness.dark,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      // Headlines
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      // Body text
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: const Color(0xFFB0B0B0),
      ),
      // Title text
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      // Serif font for special text
      labelLarge: GoogleFonts.playfairDisplay(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF2A2A2A),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6B75F2),
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF444444)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF444444)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6B75F2), width: 2),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xFFB0B0B0),
      ),
    ),
  );

  // Get current theme
  ThemeData get currentTheme =>
      _themeMode.value == ThemeMode.dark ? darkTheme : lightTheme;

  // Set theme mode
  void setThemeMode(ThemeMode mode) {
    _themeMode.value = mode;
    if (mode == ThemeMode.system) {
      // Check system theme
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _isDarkMode.value = brightness == Brightness.dark;
    } else {
      _isDarkMode.value = mode == ThemeMode.dark;
    }
    updateStatusBarStyle();
  }

  // Toggle theme
  void toggleTheme() {
    final newMode =
        _themeMode.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setThemeMode(newMode);
  }

  // Update status bar style based on current theme
  void updateStatusBarStyle() {
    final isDark = _themeMode.value == ThemeMode.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );
  }

  // Force refresh status bar style - can be called from any page
  void forceRefreshStatusBar() {
    updateStatusBarStyle();
  }
}
