/// Every playable training mode in the app.
///
/// This is the single source of truth for what games exist. It drives the home
/// screen's mode grid and the highscores board. UI concerns (icon, route) are
/// mapped in the presentation layer so this stays free of Flutter dependencies.
enum TrainingMode {
  spelling,
  math,
  simon,
  nback;

  String get label => switch (this) {
    TrainingMode.spelling => 'Spelling',
    TrainingMode.math => 'Math',
    TrainingMode.simon => 'Simon',
    TrainingMode.nback => 'N-Back',
  };

  /// Short description shown on the home tile.
  String get description => switch (this) {
    TrainingMode.spelling => 'Fill the missing letter',
    TrainingMode.math => 'Solve against the clock',
    TrainingMode.simon => 'Repeat the sequence',
    TrainingMode.nback => 'Match N steps back',
  };

  /// How this mode's highscore is described (e.g. "Best level").
  String get scoreLabel => switch (this) {
    TrainingMode.spelling => 'Best score',
    TrainingMode.math => 'Best score',
    TrainingMode.simon => 'Best level',
    TrainingMode.nback => 'Best score',
  };
}
