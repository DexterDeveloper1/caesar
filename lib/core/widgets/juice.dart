import 'dart:math' as math;

import 'package:caesar/core/design.dart';
import 'package:flutter/material.dart';

/// Reusable "game feel" widgets.
///
/// The guiding rule: every input gets immediate, readable feedback, and no
/// motion is linear. These are deliberately small and composable so any screen
/// can pick up the same feel.

/// Scales its child down while pressed, then springs back — the single most
/// effective piece of tactile feedback for touch UI.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double pressedScale;

  const Pressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.pressedScale = 0.95,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (widget.onPressed == null || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: Motion.instant,
        curve: Motion.emphasized,
        child: Opacity(opacity: enabled ? 1 : 0.5, child: widget.child),
      ),
    );
  }
}

/// Animates between integer values by counting up, so a score change reads as
/// an event rather than a silent swap.
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle? style;

  const CountUp({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: Motion.normal,
      curve: Motion.emphasized,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

/// Pops (scales up then settles) whenever [trigger] changes — used to punch
/// score increases and other positive events.
class PopOnChange extends StatefulWidget {
  final Object? trigger;
  final Widget child;
  final double scale;

  const PopOnChange({
    super.key,
    required this.trigger,
    required this.child,
    this.scale = 1.25,
  });

  @override
  State<PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<PopOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.fast,
  );

  @override
  void didUpdateWidget(PopOnChange old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Up then back down, so the element "punches" and settles.
        final t = math.sin(_controller.value * math.pi);
        return Transform.scale(scale: 1 + (widget.scale - 1) * t, child: child);
      },
      child: widget.child,
    );
  }
}

/// Shakes horizontally whenever [trigger] changes — the standard "wrong"
/// signal. Dampened, never sustained.
class ShakeOnChange extends StatefulWidget {
  final Object? trigger;
  final Widget child;
  final double amplitude;

  const ShakeOnChange({
    super.key,
    required this.trigger,
    required this.child,
    this.amplitude = 10,
  });

  @override
  State<ShakeOnChange> createState() => _ShakeOnChangeState();
}

class _ShakeOnChangeState extends State<ShakeOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.normal,
  );

  @override
  void didUpdateWidget(ShakeOnChange old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Decaying oscillation.
        final offset = math.sin(t * math.pi * 6) * widget.amplitude * (1 - t);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// A circular countdown that shifts green → amber → red as time runs out,
/// making time pressure legible at a glance.
class CountdownRing extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  final double size;

  const CountdownRing({
    super.key,
    required this.secondsLeft,
    required this.totalSeconds,
    this.size = 62,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final fraction = totalSeconds <= 0
        ? 0.0
        : (secondsLeft / totalSeconds).clamp(0.0, 1.0);
    final color = Color.lerp(
      const Color(0xFFEF4444),
      const Color(0xFF22C55E),
      // Ramp through amber rather than a flat blend.
      fraction < 0.5 ? fraction * 0.6 : fraction,
    )!;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: fraction, end: fraction),
            duration: Motion.fast,
            builder: (context, v, _) => SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                backgroundColor: palette.surfaceBorder,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          PopOnChange(
            trigger: secondsLeft,
            scale: 1.15,
            child: Text(
              '$secondsLeft',
              style: TextStyle(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of "life" pips that dim as strikes are taken — far more readable than
/// the text "Strikes: 2/3".
class LifePips extends StatelessWidget {
  final int used;
  final int total;

  const LifePips({super.key, required this.used, required this.total});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedScale(
              scale: i < total - used ? 1.0 : 0.75,
              duration: Motion.fast,
              curve: Motion.springy,
              child: Icon(
                i < total - used
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 20,
                color: i < total - used
                    ? const Color(0xFFF43F5E)
                    : palette.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

/// A one-shot particle burst, played on celebratory moments (new record,
/// finishing a session). Purely decorative and cheap — no physics engine.
class Burst extends StatefulWidget {
  final bool play;
  final int particles;

  const Burst({super.key, required this.play, this.particles = 24});

  @override
  State<Burst> createState() => _BurstState();
}

class _BurstState extends State<Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  static const List<Color> _colors = [
    Color(0xFF22D3EE),
    Color(0xFFA78BFA),
    Color(0xFFFBBF24),
    Color(0xFFF472B6),
    Color(0xFF34D399),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.play) _controller.forward();
  }

  @override
  void didUpdateWidget(Burst old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _BurstPainter(
            progress: _controller.value,
            count: widget.particles,
            colors: _colors,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final int count;
  final List<Color> colors;

  _BurstPainter({
    required this.progress,
    required this.count,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress == 1) return;
    final origin = Offset(size.width / 2, size.height * 0.38);
    final paint = Paint();
    final reach = size.shortestSide * 0.55;

    for (var i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2;
      // Ease outward and fall slightly under gravity.
      final dist = reach * Curves.easeOutCubic.transform(progress);
      final gravity = 60 * progress * progress;
      final offset = Offset(
        origin.dx + math.cos(angle) * dist,
        origin.dy + math.sin(angle) * dist + gravity,
      );
      paint.color = colors[i % colors.length].withValues(
        alpha: (1 - progress).clamp(0.0, 1.0),
      );
      canvas.drawCircle(offset, 4 * (1 - progress) + 1, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
