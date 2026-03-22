// lib/theme/app_theme.dart
// Complete theme — all color tokens, bright purple/teal palette
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ══════════════════════════════════════════════════════════════════════════════
// COLOR PALETTE
// ══════════════════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // ── Brand gradient ───────────────────────────────────────────────────────
  static const Color gradientStart = Color(0xFF2E0754);  // deep violet
  static const Color gradientMid   = Color(0xFF5B21B6);  // vivid purple
  static const Color gradientEnd   = Color(0xFF0891B2);  // teal

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color brandPurple   = Color(0xFF7C3AED);
  static const Color lightPurple   = Color(0xFFA78BFA);
  static const Color cyanAccent    = Color(0xFF14FFEC);
  static const Color onlineGreen   = Color(0xFF22C55E);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success       = Color(0xFF22C55E);
  static const Color danger        = Color(0xFFEF4444);
  static const Color warning       = Color(0xFFF59E0B);

  // ── Dark mode backgrounds ────────────────────────────────────────────────
  static const Color bgDark        = Color(0xFF0F0F14);
  static const Color cardDark      = Color(0xFF1A1A24);
  static const Color surfaceDark   = Color(0xFF22222F);
  static const Color borderDark    = Color(0xFF2E2E40);

  // ── Light mode backgrounds ───────────────────────────────────────────────
  static const Color bgLight       = Color(0xFFF2F3F8);
  static const Color cardLight     = Color(0xFFF8F9FF);
  static const Color surfaceLight  = Color(0xFFFFFFFF);
  static const Color borderLight   = Color(0xFFE2E8F0);

  // ── Text — dark mode ────────────────────────────────────────────────────
  static const Color textSoftDark  = Color(0xFF6B7280);
  static const Color textMidDark   = Color(0xFF9CA3AF);

  // ── Text — light mode ───────────────────────────────────────────────────
  static const Color textDarkLight = Color(0xFF1E1B2E);
  static const Color textMidLight  = Color(0xFF6B7280);
  static const Color textSoftLight = Color(0xFFADB5BD);
}

// ══════════════════════════════════════════════════════════════════════════════
// LIGHT THEME
// ══════════════════════════════════════════════════════════════════════════════
ThemeData get lightTheme {
  const primary = AppColors.brandPurple;

  return ThemeData(
    useMaterial3:         true,
    brightness:           Brightness.light,
    colorScheme:          ColorScheme.light(
      primary:            primary,
      secondary:          AppColors.cyanAccent,
      surface:            AppColors.bgLight,
      background:         AppColors.bgLight,
      error:              AppColors.danger,
      onPrimary:          Colors.white,
      onSecondary:        AppColors.bgDark,
      onSurface:          AppColors.textDarkLight,
    ),
    scaffoldBackgroundColor: AppColors.bgLight,
    textTheme:            GoogleFonts.poppinsTextTheme().apply(
      bodyColor:          AppColors.textDarkLight,
      displayColor:       AppColors.textDarkLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:    Colors.transparent,
      foregroundColor:    AppColors.textDarkLight,
      elevation:          0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:  primary,
        foregroundColor:  Colors.white,
        elevation:        0,
        shape:            RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor:  primary,
        side:             const BorderSide(color: AppColors.borderLight),
        shape:            RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:             true,
      fillColor:          Colors.white,
      contentPadding:     const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.borderLight)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.borderLight)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.danger)),
      hintStyle: const TextStyle(
          color: AppColors.textSoftLight, fontWeight: FontWeight.w400),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith(
              (s) => s.contains(MaterialState.selected) ? primary : Colors.white),
      trackColor: MaterialStateProperty.resolveWith(
              (s) => s.contains(MaterialState.selected)
              ? primary.withOpacity(0.4) : AppColors.borderLight),
    ),
    cardTheme: CardThemeData(
      color:       Colors.white,
      elevation:   0,
      shape:       RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:         const BorderSide(color: AppColors.borderLight)),
    ),
    dividerTheme: const DividerThemeData(
      color:       AppColors.borderLight,
      thickness:   1,
      space:       1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior:    SnackBarBehavior.floating,
      shape:       RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// DARK THEME
// ══════════════════════════════════════════════════════════════════════════════
ThemeData get darkTheme {
  const primary = AppColors.brandPurple;

  return ThemeData(
    useMaterial3:         true,
    brightness:           Brightness.dark,
    colorScheme:          ColorScheme.dark(
      primary:            primary,
      secondary:          AppColors.cyanAccent,
      surface:            AppColors.bgDark,
      background:         AppColors.bgDark,
      error:              AppColors.danger,
      onPrimary:          Colors.white,
      onSecondary:        AppColors.bgDark,
      onSurface:          Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.bgDark,
    textTheme:            GoogleFonts.poppinsTextTheme(
        ThemeData.dark().textTheme).apply(
      bodyColor:          Colors.white,
      displayColor:       Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:    Colors.transparent,
      foregroundColor:    Colors.white,
      elevation:          0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:  primary,
        foregroundColor:  Colors.white,
        elevation:        0,
        shape:            RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor:  primary,
        side:             const BorderSide(color: AppColors.borderDark),
        shape:            RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:             true,
      fillColor:          AppColors.surfaceDark,
      contentPadding:     const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.borderDark)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.borderDark)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.danger)),
      hintStyle: const TextStyle(
          color: Color(0xFF484F58), fontWeight: FontWeight.w400),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith(
              (s) => s.contains(MaterialState.selected) ? primary : AppColors.textSoftDark),
      trackColor: MaterialStateProperty.resolveWith(
              (s) => s.contains(MaterialState.selected)
              ? primary.withOpacity(0.4) : AppColors.borderDark),
    ),
    cardTheme: CardThemeData(
      color:       AppColors.cardDark,
      elevation:   0,
      shape:       RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:         const BorderSide(color: AppColors.borderDark)),
    ),
    dividerTheme: const DividerThemeData(
      color:       AppColors.borderDark,
      thickness:   1, space: 1,
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// THEME WRAPPER (used in MaterialApp)
// ══════════════════════════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();
  static ThemeData get light => lightTheme;
  static ThemeData get dark  => darkTheme;
}