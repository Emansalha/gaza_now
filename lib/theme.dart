import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color ink = Color(0xFF073B49);
const Color teal = Color(0xFF087D89);
const Color pale = Color(0xFFF2F7F8);
const Color urgent = Color(0xFFE53935);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: teal, brightness: brightness);
  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF0B1A1E) : pale,
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF0F2328) : Colors.white,
      foregroundColor: dark ? Colors.white : ink,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF14292F) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF0F2328) : Colors.white,
      indicatorColor: teal.withValues(alpha: .18),
    ),
  );
}

/// Small helpers so widgets look right in both light and dark mode.
extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get titleColor => isDark ? Colors.white : ink;
  Color get surfaceCard => isDark ? const Color(0xFF14292F) : Colors.white;
  Color get softFill => isDark ? const Color(0xFF1B3A41) : const Color(0xFFDCE9EC);
  Color get noteFill => isDark ? const Color(0xFF16333A) : const Color(0xFFE5F1F2);
}
