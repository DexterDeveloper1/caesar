import 'package:flutter/material.dart';

/// App-wide constants and design tokens.
///
/// Centralizes values that were previously hardcoded across screens so the
/// app stays visually consistent.
class AppInfo {
  static const String name = 'Caesar';
  static const String tagline = 'Train your brain the fun way!';
  static const String version = '1.0.0';
}

class GameConfig {
  /// Strikes allowed before a run ends.
  static const int maxStrikes = 3;

  /// Difficulty presets exposed in Settings, mapped to a starting difficulty.
  static const Map<String, int> difficultyPresets = {
    'Easy': 1,
    'Medium': 3,
    'Hard': 5,
  };
}

/// Shared visual tokens. Kept here so the home gradient (and future surfaces)
/// don't drift apart.
class AppGradients {
  static const LinearGradient background = LinearGradient(
    colors: [Color(0xFF2B5876), Color(0xFF4E4376)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
