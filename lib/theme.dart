import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// FitFuel colours – same palette as the web app and the design mockups.
class FF {
  static const bg = Color(0xFF0E0F0C);
  static const surface = Color(0xFF1C1E19);
  static const surface2 = Color(0xFF262922);
  static const sunk = Color(0xFF151713);
  static const line = Color(0xFF2C2F27);
  static const fg = Color(0xFFF2F3EE);
  static const muted = Color(0xFFA3A69C);
  static const accent = Color(0xFFC6F432);
  static const accentInk = Color(0xFF0E0F0C);
  static const burn = Color(0xFFFF8A3D);
  static const water = Color(0xFF6EC1FF);

  static TextStyle display(double size, {Color color = fg, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, color: color);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: FF.bg,
    colorScheme: const ColorScheme.dark(
      primary: FF.accent,
      onPrimary: FF.accentInk,
      secondary: FF.burn,
      surface: FF.surface,
      onSurface: FF.fg,
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: FF.fg, displayColor: FF.fg),
    appBarTheme: AppBarTheme(
      backgroundColor: FF.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: FF.display(24),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FF.sunk,
      labelStyle: const TextStyle(color: FF.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: FF.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: FF.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: FF.accent, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FF.accent,
        foregroundColor: FF.accentInk,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: FF.display(16, color: FF.accentInk),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: FF.fg,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: FF.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: FF.sunk,
      selectedColor: FF.accent,
      side: const BorderSide(color: FF.line),
      labelStyle: const TextStyle(color: FF.fg, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: FF.accentInk, fontWeight: FontWeight.w600),
      checkmarkColor: FF.accentInk,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: FF.sunk,
      indicatorColor: FF.surface2,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? FF.accent : FF.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? FF.accent : FF.muted,
          )),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: FF.fg,
      contentTextStyle: TextStyle(color: FF.bg, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
