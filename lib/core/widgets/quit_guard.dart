import 'package:caesar/app/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Wraps a game screen so the back gesture asks before abandoning the run.
///
/// **Quitting forfeits the run.** The score is not submitted and the session is
/// not recorded, which is deliberate: if quitting were free, the confirmation
/// dialog would double as a pause button — think about the answer, then cancel.
/// Because the clock keeps running underneath the dialog and leaving costs you
/// the whole run, there is nothing to gain by opening it.
class QuitGuard extends StatelessWidget {
  final Widget child;

  /// Shown in the dialog, e.g. 'Your score will not be saved.'
  final String message;

  /// Whether the guard is active. Results screens pass false — the run is
  /// already over, so back should simply leave.
  final bool enabled;

  const QuitGuard({
    super.key,
    required this.child,
    this.message = 'This run will end and your score will not be saved.',
    this.enabled = true,
  });

  static Future<bool> confirm(BuildContext context, String message) async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit this run?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    return quit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !enabled,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !enabled) return;
        final quit = await confirm(context, message);
        if (!quit || !context.mounted) return;
        context.go(Routes.home);
      },
      child: child,
    );
  }
}
