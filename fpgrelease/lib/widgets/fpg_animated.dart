// ============================================================
// FPG ANIMATED UI KIT
// ------------------------------------------------------------
// Reusable, self-contained animated widgets used to give screens a
// "modern sport game" (FIFA/FM-style) feel: neon glow cards, animated
// stat bars, a circular OVR gauge, a tap-timing "precision" mini-game
// bar, and a small celebratory sparkle burst.
//
// Nothing in this file touches game/simulation logic — presentation
// only, so it is safe to reuse from any screen (training, match,
// development, ...) without risking engine/test regressions.
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';

import '../core/fpg_theme.dart';

// ------------------------------------------------------------
// EA FC-style screen transition
// ------------------------------------------------------------

/// A shared page transition used across the whole app instead of the
/// platform default, so every `Navigator.push` feels like part of the same
/// "sport game menu" (subtle slide-up + fade + soft scale-in), matching the
/// entrance animation already used inside individual screens
/// (create player / club selection / career start).
///
/// Usage: `Navigator.push(context, FPGPageRoute(builder: (_) => Screen()))`
/// as a drop-in replacement for `MaterialPageRoute`.
class FPGPageRoute<T> extends PageRouteBuilder<T> {
  FPGPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            final slide = Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero).animate(curved);
            final scale = Tween<double>(begin: .98, end: 1.0).animate(curved);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: slide,
                child: ScaleTransition(scale: scale, child: child),
              ),
            );
          },
        );
}

// ------------------------------------------------------------
// Small helpers
// ------------------------------------------------------------

/// Counts a number up from 0 (or [from]) to [value] over [duration].
class CountUpNumber extends StatelessWidget {
  final int value;
  final int from;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  const CountUpNumber({
    super.key,
    required this.value,
    this.from = 0,
    this.duration = const Duration(milliseconds: 700),
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: from, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$prefix$v$suffix', style: style),
    );
  }
}

// ------------------------------------------------------------
// Glow / neon container
// ------------------------------------------------------------

class NeonGlowCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double radius;
  final EdgeInsets padding;
  final Gradient? gradient;
  final bool intense;

  const NeonGlowCard({
    super.key,
    required this.child,
    required this.glowColor,
    this.radius = 20,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.intense = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? FPGTheme.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glowColor.withValues(alpha: intense ? .55 : .28)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: intense ? .35 : .16),
            blurRadius: intense ? 28 : 18,
            spreadRadius: intense ? 1.5 : 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ------------------------------------------------------------
// Animated stat bar (pace / shooting / passing / ...)
// ------------------------------------------------------------

class AnimatedStatBar extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  final Duration delay;

  const AnimatedStatBar({
    super.key,
    required this.label,
    required this.value,
    this.max = 99,
    required this.color,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final frac = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
                color: FPGTheme.muted,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 9,
                color: FPGTheme.surface2,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: frac),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: v,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color.withValues(alpha: .65), color]),
                        boxShadow: [BoxShadow(color: color.withValues(alpha: .55), blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: CountUpNumber(
              value: value,
              duration: const Duration(milliseconds: 900),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Attribute radar (hexagon "player card" chart)
// ------------------------------------------------------------

class RadarAxis {
  final String label;
  final int value;
  final Color color;
  const RadarAxis(this.label, this.value, this.color);
}

class AttributeRadar extends StatelessWidget {
  final List<RadarAxis> axes;
  final int max;
  final double size;

  const AttributeRadar({super.key, required this.axes, this.max = 99, this.size = 220});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RadarPainter(axes: axes, max: max, t: t),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<RadarAxis> axes;
  final int max;
  final double t;
  _RadarPainter({required this.axes, required this.max, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final n = axes.length;
    if (n < 3) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 28;

    Offset pointAt(int i, double frac) {
      final angle = -pi / 2 + (2 * pi / n) * i;
      return center + Offset(cos(angle), sin(angle)) * radius * frac;
    }

    // Web (grid rings)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: .08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final ring in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = pointAt(i, ring);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
    // Spokes
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, pointAt(i, 1.0), gridPaint);
    }

    // Value polygon
    final valuePath = Path();
    for (var i = 0; i < n; i++) {
      final frac = (axes[i].value / max).clamp(0.0, 1.0) * t;
      final p = pointAt(i, frac);
      i == 0 ? valuePath.moveTo(p.dx, p.dy) : valuePath.lineTo(p.dx, p.dy);
    }
    valuePath.close();

    canvas.drawPath(
      valuePath,
      Paint()
        ..color = const Color(0xFF67D9FF).withValues(alpha: .22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      valuePath,
      Paint()
        ..color = const Color(0xFF67D9FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Vertex dots + labels
    final tp = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    for (var i = 0; i < n; i++) {
      final frac = (axes[i].value / max).clamp(0.0, 1.0) * t;
      final p = pointAt(i, frac);
      canvas.drawCircle(p, 3, Paint()..color = axes[i].color);

      final labelPos = pointAt(i, 1.18);
      tp.text = TextSpan(
        text: '${axes[i].label}\n${(axes[i].value * t).round()}',
        style: TextStyle(color: axes[i].color, fontSize: 10, fontWeight: FontWeight.w800, height: 1.2),
      );
      tp.layout(maxWidth: 56);
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.t != t || oldDelegate.axes != axes;
}

// ------------------------------------------------------------
// Circular OVR ring
// ------------------------------------------------------------

class OvrRing extends StatelessWidget {
  final int value;
  final int max;
  final double size;
  final Color color;

  const OvrRing({
    super.key,
    required this.value,
    this.max = 99,
    this.size = 84,
    this.color = const Color(0xFF67D9FF),
  });

  @override
  Widget build(BuildContext context) {
    final frac = (value / max).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: frac),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(v, color),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CountUpNumber(
                    value: value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const Text('OVR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double frac;
  final Color color;
  _RingPainter(this.frac, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final track = Paint()
      ..color = color.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = color.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    const start = -pi / 2;
    final sweep = 2 * pi * frac;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, glow);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.frac != frac || oldDelegate.color != color;
}

// ------------------------------------------------------------
// Pulsing icon — glowing halo that breathes in and out. Used for
// "action available today" style banners across screens.
// ------------------------------------------------------------

class PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool pulse;
  final double size;
  const PulsingIcon({super.key, required this.icon, required this.color, this.pulse = true, this.size = 24});

  @override
  State<PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<PulsingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) return Icon(widget.icon, color: widget.color, size: widget.size);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: .25 + .35 * _c.value), blurRadius: 12 + 8 * _c.value)],
        ),
        child: Icon(widget.icon, color: widget.color, size: widget.size),
      ),
    );
  }
}

// ------------------------------------------------------------
// Perk / achievement tile with a satisfying unlock animation
// ------------------------------------------------------------

class PerkTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool unlocked;
  final String condition;
  final Color color;

  const PerkTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    required this.condition,
    this.color = const Color(0xFF43FFAF),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: unlocked ? FPGTheme.surface : Colors.white.withValues(alpha: .02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: unlocked ? color.withValues(alpha: .4) : Colors.white.withValues(alpha: .06)),
        boxShadow: unlocked ? [BoxShadow(color: color.withValues(alpha: .18), blurRadius: 16)] : [],
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: unlocked ? 1 : 0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, v, _) => Transform.scale(
              scale: 0.7 + 0.3 * v,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked ? color.withValues(alpha: .18) : Colors.white.withValues(alpha: .04),
                ),
                child: Icon(unlocked ? Icons.verified_rounded : Icons.lock_outline_rounded,
                    color: unlocked ? color : Colors.white24, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: unlocked ? FPGTheme.textPrimary : FPGTheme.muted)),
                const SizedBox(height: 2),
                Text(
                  unlocked ? subtitle : 'Zablokowano: $condition',
                  style: TextStyle(fontSize: 12, color: unlocked ? FPGTheme.muted : Colors.white24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// PRECISION MINI-GAME BAR
// A marker sweeps left/right across colored zones; the player taps to
// lock it in place. Distance from the exact center decides the zone.
// Purely a presentation/"feel" layer — callers decide what (if
// anything) to do with the result.
// ------------------------------------------------------------

enum PrecisionZone { perfect, good, ok, miss }

extension PrecisionZoneLabel on PrecisionZone {
  String get label => switch (this) {
        PrecisionZone.perfect => 'PERFEKCYJNIE!',
        PrecisionZone.good => 'DOBRZE',
        PrecisionZone.ok => 'OK',
        PrecisionZone.miss => 'SŁABO',
      };

  Color get color => switch (this) {
        PrecisionZone.perfect => const Color(0xFF43FFAF),
        PrecisionZone.good => const Color(0xFF67D9FF),
        PrecisionZone.ok => const Color(0xFFFFC24B),
        PrecisionZone.miss => const Color(0xFFFF6B6B),
      };
}

class PrecisionResult {
  final PrecisionZone zone;
  final double value;
  const PrecisionResult(this.zone, this.value);
}

class PrecisionBar extends StatefulWidget {
  final Color accent;
  final ValueChanged<PrecisionResult> onLocked;
  final Duration sweepDuration;
  final double height;

  const PrecisionBar({
    super.key,
    required this.accent,
    required this.onLocked,
    this.sweepDuration = const Duration(milliseconds: 900),
    this.height = 46,
  });

  @override
  State<PrecisionBar> createState() => _PrecisionBarState();
}

class _PrecisionBarState extends State<PrecisionBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _locked = false;
  double _lockedValue = 0.5;

  static const List<(double, PrecisionZone)> _bandEdges = [
    (0.05, PrecisionZone.perfect),
    (0.15, PrecisionZone.good),
    (0.30, PrecisionZone.ok),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.sweepDuration)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  PrecisionZone _zoneFor(double v) {
    final d = (v - 0.5).abs();
    for (final (edge, zone) in _bandEdges) {
      if (d <= edge) return zone;
    }
    return PrecisionZone.miss;
  }

  void _lock() {
    if (_locked) return;
    final v = _c.value;
    final zone = _zoneFor(v);
    setState(() {
      _locked = true;
      _lockedValue = v;
    });
    _c.stop();
    widget.onLocked(PrecisionResult(zone, v));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _lock,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
              color: FPGTheme.surface2,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Row(
                  children: const [
                    _Zone(flex: 20, color: Color(0xFFFF6B6B)),
                    _Zone(flex: 15, color: Color(0xFFFFC24B)),
                    _Zone(flex: 10, color: Color(0xFF67D9FF)),
                    _Zone(flex: 10, color: Color(0xFF43FFAF)),
                    _Zone(flex: 10, color: Color(0xFF67D9FF)),
                    _Zone(flex: 15, color: Color(0xFFFFC24B)),
                    _Zone(flex: 20, color: Color(0xFFFF6B6B)),
                  ],
                ),
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final v = _locked ? _lockedValue : _c.value;
                    return Positioned(
                      left: (v * w - 3).clamp(0.0, w - 6),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 6,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(color: widget.accent.withValues(alpha: .9), blurRadius: 14, spreadRadius: 1),
                            const BoxShadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Zone extends StatelessWidget {
  final int flex;
  final Color color;
  const _Zone({required this.flex, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(color: color.withValues(alpha: .35)),
    );
  }
}

// ------------------------------------------------------------
// Sparkle burst — short celebratory flourish for great results.
// ------------------------------------------------------------

class SparkleBurst extends StatefulWidget {
  final Color color;
  final double size;
  const SparkleBurst({super.key, required this.color, this.size = 120});

  @override
  State<SparkleBurst> createState() => _SparkleBurstState();
}

class _SparkleBurstState extends State<SparkleBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final int _count = 10;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_c.value);
          final fade = 1 - _c.value;
          return Stack(
            alignment: Alignment.center,
            children: List.generate(_count, (i) {
              final angle = (2 * pi / _count) * i;
              final dist = t * widget.size / 2;
              return Opacity(
                opacity: fade.clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(cos(angle) * dist, sin(angle) * dist),
                  child: Icon(Icons.star_rounded, color: widget.color, size: 12 + 6 * (1 - t)),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
