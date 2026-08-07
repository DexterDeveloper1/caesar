import 'package:flutter/material.dart';

/// App theme. Light and dark are derived from a single seed color so surfaces,
/// buttons, and text stay consistent across screens.
class CaesarTheme {
  static const Color seedColor = Colors.deepPurple;

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  static final ThemeData lightTheme = _base(Brightness.light);
  static final ThemeData darkTheme = _base(Brightness.dark);
}
