import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum GameType { spelling, math }

class GameScreen extends StatefulWidget {
  final GameType mode;

  const GameScreen({super.key, required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late String question;
  late String answer;
  int score = 0;
  int strikes = 0;
  int difficulty = 1;
  int timeLeft = 10;
  bool isGameOver = false;

  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generateQuestion();
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      if (isGameOver || !mounted) return false;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      setState(() {
        timeLeft--;
      });

      if (timeLeft <= 0) {
        _fail();
        return false;
      }
      return true;
    });
  }

  void _generateQuestion() {
    if (widget.mode == GameType.math) {
      final rand = Random();
      int a = rand.nextInt(10 * difficulty) + 1;
      int b = rand.nextInt(10 * difficulty) + 1;
      List<String> ops = ['+', '-', '×', '÷'];
      String op = ops[rand.nextInt(min(ops.length, 2 + difficulty ~/ 2))];

      switch (op) {
        case '+':
          answer = (a + b).toString();
          break;
        case '-':
          answer = (a - b).toString();
          break;
        case '×':
          answer = (a * b).toString();
          break;
        case '÷':
          answer = (a ~/ b).toString();
          break;
        default:
          answer = '';
      }

      question = '$a $op $b = ?';
    } else {
      // Simple spelling: missing a letter
      final words = [
        'cat',
        'train',
        'school',
        'banana',
        'keyboard',
        'flutter',
        'electric',
      ];
      final rand = Random();
      final word = words[rand.nextInt(words.length)];
      final missingIndex = rand.nextInt(word.length);
      answer = word[missingIndex];
      question = word.replaceRange(missingIndex, missingIndex + 1, '_');
    }

    timeLeft = max(5, 12 - difficulty);
  }

  void _submit() {
    if (controller.text.trim().toLowerCase() == answer.toLowerCase()) {
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
      if (strikes >= 3) {
        isGameOver = true;
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
      _generateQuestion();
      _startTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isGameOver) {
      return Scaffold(
        backgroundColor: Colors.red.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.close, color: Colors.red, size: 80),
              const SizedBox(height: 16),
              Text(
                'Game Over',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text('Score: $score'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _restartGame,
                child: const Text('Restart'),
              ),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == GameType.math ? 'Math Mode' : 'Spelling Mode',
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Score: $score'),
                Text('Strikes: $strikes/3'),
                Text('Time: $timeLeft'),
              ],
            ),
            const SizedBox(height: 40),
            Text(question, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
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
