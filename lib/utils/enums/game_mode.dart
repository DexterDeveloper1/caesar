enum GameMode {
  easy,
  medium,
  hard,
  expert;

  static GameMode fromString(String mode) {
    return GameMode.values.firstWhere(
      (m) => m.name == mode,
      orElse: () => GameMode.easy,
    );
  }
}
