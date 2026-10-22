import 'package:flutter/material.dart';

class AppTheme {
  // Graphite surfaces and soft blue accents inspired by the reference UI.
  static const Color darkBackground = Color(0xFF0B0D0F);
  static const Color surfaceDark = Color(0xFF111416);
  static const Color cardNavy = Color(0xFF1A1D20);
  static const Color surfaceLight = Color(0xFF25292D);

  static const Color primaryPurple = Color(0xFFB8D8F4);
  static const Color accentCyan = Color(0xFFAED5F3);
  static const Color gradientPurple = Color(0xFFD5E8F8);

  static const Color textWhite = Color(0xFFF2F4F6);
  static const Color textMuted = Color(0xFF8E969E);
  static const Color successGreen = Color(0xFF8EE6A8);
  static const Color warningOrange = Color(0xFFF2C47A);
  static const Color urgentRed = Color(0xFFF18B91);

  // Category Accent Color Tokens
  static const Color categoryPersonal = Color(0xFFBFDDF5);
  static const Color categoryWork = Color(0xFF9DC7E8);
  static const Color categoryStudy = Color(0xFF9CE0B3);
  static const Color categoryHealth = Color(0xFFE7B4C0);
  static const Color categoryShopping = Color(0xFFEAC98F);
  static const Color categoryMeetings = Color(0xFFA9DCE0);
  static const Color categoryBills = Color(0xFFE6A3A8);
  static const Color categoryFamily = Color(0xFFC0BCE9);
  static const Color categoryCoding = Color(0xFF9ED8CE);

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
    colors: [Color(0xFFD9ECFA), Color(0xFF9FC8E8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF2A2E32), cardNavy],
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
        elevation: 0,
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
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(radiusXL)),
          side: BorderSide(color: primaryPurple.withValues(alpha: 0.3)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardNavy,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        backgroundColor: Color(0xFF111315),
        selectedItemColor: primaryPurple,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF111315),
        indicatorColor: primaryPurple,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? darkBackground
                : textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? darkBackground
                : textMuted,
            size: 21,
          ),
        ),
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
