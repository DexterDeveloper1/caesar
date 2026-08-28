import 'package:caesar/core/training_mode.dart';
import 'package:flutter/material.dart';

/// Design tokens for the app.
///
/// Everything visual — spacing, radii, motion timings, per-mode identity — is
/// defined here so screens stay consistent and the look can be retuned in one
/// place.
class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class Radii {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 26;
  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Motion durations. Short and eased — never linear, so interactions feel
/// physical rather than mechanical.
class Motion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 600);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve springy = Curves.easeOutBack;
}

/// The visual identity of a single training mode: its accent colours and icon.
///
/// Giving each mode its own colour makes the app read as a set of distinct
/// games rather than one undifferentiated list.
@immutable
class ModeStyle {
  final Color start;
  final Color end;
  final IconData icon;

  const ModeStyle({required this.start, required this.end, required this.icon});

  LinearGradient get gradient => LinearGradient(
    colors: [start, end],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Accent used for text/among neutral surfaces.
  Color get accent => start;
}

/// Per-mode styling, keyed by [TrainingMode].
const Map<TrainingMode, ModeStyle> modeStyles = {
  TrainingMode.spelling: ModeStyle(
    start: Color(0xFF22D3EE),
    end: Color(0xFF0284C7),
    icon: Icons.spellcheck_rounded,
  ),
  TrainingMode.math: ModeStyle(
    start: Color(0xFFA78BFA),
    end: Color(0xFF6D28D9),
    icon: Icons.calculate_rounded,
  ),
  TrainingMode.simon: ModeStyle(
    start: Color(0xFFFBBF24),
    end: Color(0xFFEA580C),
    icon: Icons.grid_view_rounded,
  ),
  TrainingMode.nback: ModeStyle(
    start: Color(0xFFF472B6),
    end: Color(0xFFBE185D),
    icon: Icons.memory_rounded,
  ),
};

ModeStyle styleOf(TrainingMode mode) => modeStyles[mode]!;

/// Background and surface colours, adapted to the active brightness so the
/// user's light/dark preference is still respected.
@immutable
class AppPalette {
  final List<Color> backdrop;
  final Color surface;
  final Color surfaceBorder;
  final Color textPrimary;
  final Color textMuted;

  const AppPalette({
    required this.backdrop,
    required this.surface,
    required this.surfaceBorder,
    required this.textPrimary,
    required this.textMuted,
  });

  static const AppPalette dark = AppPalette(
    backdrop: [Color(0xFF0B1020), Color(0xFF1B1440), Color(0xFF0B1020)],
    surface: Color(0x14FFFFFF),
    surfaceBorder: Color(0x1FFFFFFF),
    textPrimary: Color(0xFFF8FAFC),
    textMuted: Color(0xB3E2E8F0),
  );

  static const AppPalette light = AppPalette(
    backdrop: [Color(0xFFEEF2FF), Color(0xFFF8FAFF), Color(0xFFEDE9FE)],
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0x14000000),
    textPrimary: Color(0xFF0F172A),
    textMuted: Color(0xB3334155),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  LinearGradient get backgroundGradient => LinearGradient(
    colors: backdrop,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Full-bleed gradient background used by the immersive screens.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: palette.backgroundGradient),
      child: child,
    );
  }
}

/// A translucent, rounded panel — the app's standard content container.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.md),
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? palette.surface : null,
        gradient: gradient,
        borderRadius: Radii.card,
        border: Border.all(color: palette.surfaceBorder),
      ),
      child: child,
    );
  }
}
