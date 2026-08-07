import 'package:caesar/app/router.dart';
import 'package:caesar/core/constants.dart';
import 'package:caesar/features/game/logic/game_controller.dart';
import 'package:caesar/features/game/logic/game_type.dart';
import 'package:caesar/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GameScreen extends ConsumerStatefulWidget {
  final GameType mode;

  const GameScreen({super.key, required this.mode});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    ref
        .read(gameControllerProvider(widget.mode).notifier)
        .submit(_controller.text);
    _controller.clear();
  }

  void _restart() {
    ref.read(gameControllerProvider(widget.mode).notifier).restart();
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Play feedback based on how the state changed, keeping the controller
    // free of UI/platform side effects.
    ref.listen(gameControllerProvider(widget.mode), (previous, next) {
      if (previous == null) return;
      final audio = ref.read(audioServiceProvider);
      if (next.isGameOver && !previous.isGameOver) {
        audio.gameOver();
      } else if (next.score > previous.score) {
        audio.correct();
      } else if (next.strikes > previous.strikes) {
        audio.wrong();
      }
    });

    final state = ref.watch(gameControllerProvider(widget.mode));

    if (state.isGameOver) {
      return _GameOverView(score: state.score, onRestart: _restart);
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
                Text('Score: ${state.score}'),
                Text('Strikes: ${state.strikes}/${GameConfig.maxStrikes}'),
                Semantics(
                  liveRegion: true,
                  label: '${state.timeLeft} seconds left',
                  child: Text('Time: ${state.timeLeft}'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Semantics(
              label: 'Question',
              child: Text(
                state.prompt,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
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
            Text(
              'Game Over',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
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
