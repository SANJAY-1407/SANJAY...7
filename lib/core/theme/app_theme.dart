import 'package:flutter/material.dart';

class AppTheme {
  // Brand Color Tokens (OxygenOS-Inspired Charcoal & Vibrant Accents)
  static const Color darkBackground = Color(0xFF0D0E15);
  static const Color surfaceDark = Color(0xFF161826);
  static const Color cardNavy = Color(0xFF1A1C2E);
  static const Color surfaceLight = Color(0xFF23253B);
  
  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color gradientPurple = Color(0xFFA855F7);
  
  static const Color textWhite = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color urgentRed = Color(0xFFEF4444);

  // Category Accent Color Tokens
  static const Color categoryPersonal = Color(0xFFA855F7); // Lavender
  static const Color categoryWork = Color(0xFF3B82F6);     // Royal Blue
  static const Color categoryStudy = Color(0xFF10B981);    // Emerald Green
  static const Color categoryHealth = Color(0xFFEC4899);   // Rose Pink
  static const Color categoryShopping = Color(0xFFF59E0B); // Amber
  static const Color categoryMeetings = Color(0xFF06B6D4); // Cyan
  static const Color categoryBills = Color(0xFFEF4444);    // Red
  static const Color categoryFamily = Color(0xFF6366F1);   // Indigo
  static const Color categoryCoding = Color(0xFF14B8A6);   // Teal

  // Priority Color Tokens
  static const Color priorityHigh = urgentRed;
  static const Color priorityMedium = warningOrange;
  static const Color priorityLow = accentCyan;

  // Corner Radius Tokens
  static const double radiusS = 10.0;
  static const double radiusM = 16.0;
  static const double radiusL = 20.0;
  static const double radiusXL = 24.0;

  // Premium Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surfaceLight, cardNavy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient progressGradient = LinearGradient(
    colors: [gradientPurple, accentCyan],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Dark Theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: accentCyan,
        surface: cardNavy,
        onSurface: textWhite,
        error: urgentRed,
      ),
      cardTheme: CardThemeData(
        color: cardNavy,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXL),
          side: BorderSide(color: primaryPurple.withValues(alpha: 0.3)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardNavy,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(radiusXL)),
          side: BorderSide(color: primaryPurple.withValues(alpha: 0.3)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardNavy,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(
            color: primaryPurple.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: accentCyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: urgentRed, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textWhite),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: textWhite,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          elevation: 6,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentCyan,
          side: BorderSide(color: accentCyan.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryPurple,
        foregroundColor: textWhite,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF13141F),
        selectedItemColor: accentCyan,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
    );
  }

  // Light Theme fallback (pre-configured for future light theme support)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      colorScheme: const ColorScheme.light(
        primary: primaryPurple,
        secondary: accentCyan,
        surface: Colors.white,
      ),
    );
  }
}
