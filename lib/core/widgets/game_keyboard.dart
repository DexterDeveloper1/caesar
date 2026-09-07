import 'package:caesar/core/design.dart';
import 'package:caesar/core/widgets/juice.dart';
import 'package:flutter/material.dart';

enum KeyboardLayout { letters, digits }

/// An in-app keyboard for the timed games.
///
/// The system keyboard is a poor fit here for two reasons:
///
/// * **Latency.** Its show/hide animation runs ~250ms, which is dead time on a
///   running clock, and it resizes the screen every time it appears.
/// * **It can give the answer away.** Autocorrect and the predictive-text strip
///   will happily suggest the very word a spelling round is testing.
///
/// This keyboard is always on screen, never animates in, and offers nothing but
/// the keys the current game needs.
class GameKeyboard extends StatelessWidget {
  final KeyboardLayout layout;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final Color accent;

  const GameKeyboard({
    super.key,
    required this.layout,
    required this.onKey,
    required this.onBackspace,
    required this.onSubmit,
    required this.accent,
  });

  static const List<String> _letterRows = [
    'qwertyuiop',
    'asdfghjkl',
    'zxcvbnm',
  ];
  static const List<String> _digitRows = ['12345', '67890'];

  @override
  Widget build(BuildContext context) {
    final rows = layout == KeyboardLayout.letters ? _letterRows : _digitRows;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows) ...[
          _Row(
            children: [
              for (final char in row.split(''))
                _Key(
                  label: char.toUpperCase(),
                  onTap: () => onKey(char),
                  accent: accent,
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        _Row(
          children: [
            _Key(
              icon: Icons.backspace_outlined,
              onTap: onBackspace,
              accent: accent,
              flex: 3,
            ),
            _Key(
              icon: Icons.keyboard_return_rounded,
              onTap: onSubmit,
              accent: accent,
              flex: 4,
              filled: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final List<Widget> children;

  const _Row({required this.children});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: children);
}

class _Key extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color accent;
  final int flex;
  final bool filled;

  const _Key({
    this.label,
    this.icon,
    required this.onTap,
    required this.accent,
    this.flex = 1,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Pressable(
          onPressed: onTap,
          pressedScale: 0.9,
          child: Container(
            // Roughly the height of a system keyboard key, and comfortably
            // tappable on the narrowest phones.
            height: 46,
            decoration: BoxDecoration(
              color: filled ? accent : palette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.surfaceBorder),
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(
                    icon,
                    size: 20,
                    color: filled ? Colors.white : palette.textPrimary,
                  )
                : FittedBox(
                    child: Text(
                      label!,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
