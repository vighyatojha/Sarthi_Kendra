// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Brand (shared with Trouble Sarthi) ──────────────────────
  static const Color brandPurple    = Color(0xFF7C3AED);
  static const Color lightPurple    = Color(0xFFC4B5FD);
  static const Color success        = Color(0xFF059669);
  static const Color danger         = Color(0xFFDC2626);
  static const Color warning        = Color(0xFFD97706);

  // ── Sarthi Kendra Identity ───────────────────────────────────
  static const Color gradientStart  = Color(0xFF0F2027);
  static const Color gradientMid    = Color(0xFF203A43);
  static const Color gradientEnd    = Color(0xFF2C5364);
  static const Color cyanAccent     = Color(0xFF14FFEC);
  static const Color onlineGreen    = Color(0xFF22C55E);

  // ── Light Mode ───────────────────────────────────────────────
  static const Color bgLight        = Color(0xFFEEF2FF);
  static const Color cardLight      = Color(0xFFF0F4FF);
  static const Color surfaceLight   = Color(0xFFFFFFFF);
  static const Color textDarkLight  = Color(0xFF0F172A);
  static const Color textMidLight   = Color(0xFF475569);
  static const Color textSoftLight  = Color(0xFF94A3B8);
  static const Color borderLight    = Color(0xFFE2E8F0);

  // ── Dark Mode ────────────────────────────────────────────────
  static const Color bgDark         = Color(0xFF0D1117);
  static const Color cardDark       = Color(0xFF161B22);
  static const Color surfaceDark    = Color(0xFF1C2333);
  static const Color textDarkDark   = Color(0xFFE6EDF3);
  static const Color textMidDark    = Color(0xFF8B949E);
  static const Color textSoftDark   = Color(0xFF484F58);
  static const Color borderDark     = Color(0xFF30363D);
}

class AppTheme {
  // ─────────────────────────── LIGHT ───────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bgLight,
    colorScheme: ColorScheme.light(
      primary:      AppColors.brandPurple,
      secondary:    AppColors.cyanAccent,
      surface:      AppColors.surfaceLight,
      background:   AppColors.bgLight,
      onPrimary:    Colors.white,
      onSecondary:  AppColors.gradientStart,
      onSurface:    AppColors.textDarkLight,
      onBackground: AppColors.textDarkLight,
      error:        AppColors.danger,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
      displayLarge:  const TextStyle(color: AppColors.textDarkLight, fontWeight: FontWeight.w800),
      headlineMedium: const TextStyle(color: AppColors.textDarkLight, fontWeight: FontWeight.w700),
      bodyLarge:     const TextStyle(color: AppColors.textDarkLight),
      bodyMedium:    const TextStyle(color: AppColors.textMidLight),
      bodySmall:     const TextStyle(color: AppColors.textSoftLight),
    ),
    cardTheme: CardThemeData(
      color:       AppColors.cardLight,
      elevation:   0,
      shape:       RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:       true,
      fillColor:    AppColors.surfaceLight,
      border:       OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: AppColors.brandPurple, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:   AppColors.brandPurple,
        foregroundColor:   Colors.white,
        elevation:         0,
        padding:           const EdgeInsets.symmetric(vertical: 16),
        shape:             RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle:         const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.cyanAccent;
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.gradientEnd;
        return AppColors.borderLight;
      }),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      selectedItemColor: AppColors.brandPurple,
      unselectedItemColor: AppColors.textSoftLight,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    appBarTheme: const AppBarTheme(
      elevation:       0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      iconTheme:       IconThemeData(color: AppColors.textDarkLight),
      titleTextStyle:  TextStyle(
        color:      AppColors.textDarkLight,
        fontSize:   18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  // ─────────────────────────── DARK ────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgDark,
    colorScheme: ColorScheme.dark(
      primary:      AppColors.brandPurple,
      secondary:    AppColors.cyanAccent,
      surface:      AppColors.cardDark,
      background:   AppColors.bgDark,
      onPrimary:    Colors.white,
      onSecondary:  AppColors.gradientStart,
      onSurface:    AppColors.textDarkDark,
      onBackground: AppColors.textDarkDark,
      error:        AppColors.danger,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge:   const TextStyle(color: AppColors.textDarkDark, fontWeight: FontWeight.w800),
      headlineMedium: const TextStyle(color: AppColors.textDarkDark, fontWeight: FontWeight.w700),
      bodyLarge:      const TextStyle(color: AppColors.textDarkDark),
      bodyMedium:     const TextStyle(color: AppColors.textMidDark),
      bodySmall:      const TextStyle(color: AppColors.textSoftDark),
    ),
    cardTheme: CardThemeData(
      color:     AppColors.cardDark,
      elevation: 0,
      shape:     RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderDark, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:       true,
      fillColor:    AppColors.surfaceDark,
      border:       OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: AppColors.brandPurple, width: 2),
      ),
      labelStyle:    const TextStyle(color: AppColors.textMidDark),
      hintStyle:     const TextStyle(color: AppColors.textSoftDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:   AppColors.brandPurple,
        foregroundColor:   Colors.white,
        elevation:         0,
        padding:           const EdgeInsets.symmetric(vertical: 16),
        shape:             RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle:         const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.cyanAccent;
        return AppColors.textMidDark;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.gradientEnd;
        return AppColors.borderDark;
      }),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardDark,
      selectedItemColor: AppColors.brandPurple,
      unselectedItemColor: AppColors.textSoftDark,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    appBarTheme: const AppBarTheme(
      elevation:       0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      iconTheme:       IconThemeData(color: AppColors.textDarkDark),
      titleTextStyle:  TextStyle(
        color:      AppColors.textDarkDark,
        fontSize:   18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}