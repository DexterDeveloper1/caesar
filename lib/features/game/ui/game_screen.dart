import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caesar/app/router.dart';

/// The kind of exercise a game session runs.
enum GameType {
  spelling,
  math;

  /// Parses a route parameter into a [GameType], defaulting to [spelling]
  /// for anything unrecognized.
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

class GameScreen extends StatefulWidget {
  final GameType mode;

  const GameScreen({super.key, required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int maxStrikes = 3;
  static const List<String> _words = [
    'cat',
    'train',
    'school',
    'banana',
    'keyboard',
    'flutter',
    'electric',
  ];

  final Random _rng = Random();
  final TextEditingController controller = TextEditingController();

  late String question;
  late String answer;
  int score = 0;
  int strikes = 0;
  int difficulty = 1;
  int timeLeft = 10;
  bool isGameOver = false;

  /// Single owned timer. Storing it (rather than spawning `Future.doWhile`
  /// loops) prevents the double-speed countdown bug on restart.
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _generateQuestion();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => timeLeft--);
      if (timeLeft <= 0) _fail();
    });
  }

  void _generateQuestion() {
    if (widget.mode == GameType.math) {
      _generateMathQuestion();
    } else {
      _generateSpellingQuestion();
    }
    timeLeft = max(5, 12 - difficulty);
  }

  void _generateMathQuestion() {
    // Only expose ×/÷ as difficulty climbs.
    final ops = ['+', '-', '×', '÷'];
    final op = ops[_rng.nextInt(min(ops.length, 2 + difficulty ~/ 2))];
    int a = _rng.nextInt(10 * difficulty) + 1;
    int b = _rng.nextInt(10 * difficulty) + 1;

    switch (op) {
      case '+':
        answer = (a + b).toString();
      case '-':
        // Keep results non-negative for young learners.
        if (b > a) (a, b) = (b, a);
        answer = (a - b).toString();
      case '×':
        answer = (a * b).toString();
      case '÷':
        // Build a division that divides evenly, so the answer is exact.
        answer = a.toString();
        b = _rng.nextInt(9) + 1;
        final product = a * b;
        question = '$product ÷ $b = ?';
        return;
    }
    question = '$a $op $b = ?';
  }

  void _generateSpellingQuestion() {
    final word = _words[_rng.nextInt(_words.length)];
    final missingIndex = _rng.nextInt(word.length);
    answer = word[missingIndex];
    question = word.replaceRange(missingIndex, missingIndex + 1, '_');
  }

  void _submit() {
    final correct =
        controller.text.trim().toLowerCase() == answer.toLowerCase();
    if (correct) {
      setState(() {
        score++;
        difficulty++;
        controller.clear();
        _generateQuestion();
      });
    } else {
      _fail();
    }
  }

  void _fail() {
    setState(() {
      strikes++;
      controller.clear();
      if (strikes >= maxStrikes) {
        isGameOver = true;
        _timer?.cancel();
      } else {
        _generateQuestion();
      }
    });
  }

  void _restartGame() {
    setState(() {
      score = 0;
      strikes = 0;
      difficulty = 1;
      isGameOver = false;
      controller.clear();
      _generateQuestion();
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      return _GameOverView(score: score, onRestart: _restartGame);
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.mode.label), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Score: $score'),
                Text('Strikes: $strikes/$maxStrikes'),
                Text('Time: $timeLeft'),
              ],
            ),
            const SizedBox(height: 40),
            Text(question, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'Your answer',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _submit, child: const Text('Submit')),
          ],
        ),
      ),
    );
  }
}

class _GameOverView extends StatelessWidget {
  final int score;
  final VoidCallback onRestart;

  const _GameOverView({required this.score, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.close, color: Colors.red, size: 80),
            const SizedBox(height: 16),
            Text('Game Over', style: Theme.of(context).textTheme.headlineMedium),
            Text('Score: $score'),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRestart, child: const Text('Restart')),
            TextButton(
              onPressed: () => context.go(Routes.home),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
