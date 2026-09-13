import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  
  static const Color secondary = Color(0xFF06B6D4);
  static const Color cyan = Color(0xFF06B6D4); // Cyan
  static const Color accent = Color(0xFFEC4899); // Pink
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  
  // Dark Surface Colors
  static const Color bgDark = Color(0xFF0B0F19); // Ultra deep space
  static const Color surfaceDark = Color(0xFF111827); // Dark slate
  static const Color cardDark = Color(0xFF1E293B); // Slate 800
  static const Color cardLightDark = Color(0xFF334155);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFD946EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0x2A334155), Color(0x1A1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient neonGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surfaceDark,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFF1F5F9),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme.copyWith(
          displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
          displayMedium: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
          titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
          titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0)),
          bodyLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFFCBD5E1), height: 1.5),
          bodyMedium: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      cardTheme: CardTheme(
        color: cardDark.withOpacity(0.7),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x33475569), width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryLight,
        unselectedItemColor: Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
    );
  }
}
