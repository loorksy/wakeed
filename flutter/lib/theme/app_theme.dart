import 'package:flutter/material.dart';

class WakeedColors {
  static const darkBg = Color(0xFF0B0F14);
  static const darkElevated = Color(0xFF111820);
  static const darkSurface = Color(0xFF151C26);
  static const darkSurface2 = Color(0xFF1A2330);
  static const darkBorder = Color(0xFF263244);
  static const darkText = Color(0xFFE8EDF4);
  static const darkMuted = Color(0xFF8B9CB3);
  static const accent = Color(0xFF14B8A6);
  static const accentStrong = Color(0xFF0F766E);
  static const green = Color(0xFF4ADE80);
  static const err = Color(0xFFF87171);
  static const pink = Color(0xFFFB7185);
  static const warn = Color(0xFFFBBF24);

  static const lightBg = Color(0xFFEEF1F6);
  static const lightElevated = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFDBE3EE);
  static const lightText = Color(0xFF0F172A);
  static const lightMuted = Color(0xFF64748B);
  static const lightAccent = Color(0xFF0D9488);
}

ThemeData wakeedTheme({required bool dark}) {
  final scheme = dark
      ? const ColorScheme.dark(
          primary: WakeedColors.accent,
          onPrimary: Colors.black,
          surface: WakeedColors.darkSurface,
          onSurface: WakeedColors.darkText,
          error: WakeedColors.err,
          secondary: WakeedColors.accentStrong,
        )
      : const ColorScheme.light(
          primary: WakeedColors.lightAccent,
          onPrimary: Colors.white,
          surface: WakeedColors.lightSurface,
          onSurface: WakeedColors.lightText,
          error: Color(0xFFDC2626),
          secondary: WakeedColors.accentStrong,
        );
  final muted = dark ? WakeedColors.darkMuted : WakeedColors.lightMuted;
  final onSurface = dark ? WakeedColors.darkText : WakeedColors.lightText;
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    fontFamily: 'Tahoma',
  );
  return base.copyWith(
    scaffoldBackgroundColor: dark ? WakeedColors.darkBg : WakeedColors.lightBg,
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 13, height: 1.25, color: onSurface),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.3, color: onSurface),
      bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.3, color: muted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xEB0B0F14) : const Color(0xF0FFFFFF),
      foregroundColor: dark ? WakeedColors.darkText : WakeedColors.lightText,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        fontFamily: 'Tahoma',
        color: onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? WakeedColors.darkSurface2 : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: dark ? WakeedColors.darkBorder : WakeedColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: dark ? WakeedColors.darkBorder : WakeedColors.lightBorder),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      isDense: true,
      hintStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: muted.withValues(alpha: 0.42)),
      labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: muted.withValues(alpha: 0.85)),
      floatingLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
      helperStyle: TextStyle(fontSize: 10, color: muted.withValues(alpha: 0.7)),
    ),
    cardTheme: CardThemeData(
      color: dark ? WakeedColors.darkSurface : WakeedColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dark ? WakeedColors.darkBorder : WakeedColors.lightBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: WakeedColors.accent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    ),
  );
}
