/// The kind of exercise a game session runs.
///
/// Lives in the logic layer (not the UI) so controllers, generators, and the
/// router can all depend on it without importing widgets.
enum GameType {
  spelling,
  math;

  /// Parses a route parameter into a [GameType], defaulting to [spelling]
  /// for anything unrecognized or null.
  static GameType fromString(String? value) {
    return GameType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => GameType.spelling,
    );
  }

  String get label => switch (this) {
    GameType.math => 'Math Mode',
    GameType.spelling => 'Spelling Mode',
  };
}
