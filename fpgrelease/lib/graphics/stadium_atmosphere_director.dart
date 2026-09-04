import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/match_2d.dart';

/// Presentation-only stadium atmosphere state. The match engine remains authoritative.
class StadiumAtmosphereDirector {
  double intensity = .45;
  double targetIntensity = .45;
  double eventPulse = 0;
  double homeEnergy = .5;
  double awayEnergy = .5;
  Match2DEventType? activeEvent;
  String? eventLabel;
  double eventTimer = 0;

  void reset() {
    intensity = .45;
    targetIntensity = .45;
    eventPulse = 0;
    homeEnergy = .5;
    awayEnergy = .5;
    activeEvent = null;
    eventLabel = null;
    eventTimer = 0;
  }

  void onEvent(Match2DEvent event, Match2DState state) {
    activeEvent = event.type;
    eventTimer = event.type == Match2DEventType.goal ? 3.0 : 1.5;
    eventLabel = _label(event.type);
    final isHome = _teamForPlayer(event.playerId, state) == Match2DTeam.home;
    switch (event.type) {
      case Match2DEventType.goal:
        eventPulse = 1.0;
        if (isHome) homeEnergy = min(1, homeEnergy + .32); else awayEnergy = min(1, awayEnergy + .32);
        break;
      case Match2DEventType.shot:
      case Match2DEventType.save:
      case Match2DEventType.corner:
        eventPulse = .55;
        break;
      case Match2DEventType.card:
      case Match2DEventType.foul:
        eventPulse = .35;
        break;
      case Match2DEventType.halftime:
      case Match2DEventType.fulltime:
        eventPulse = .7;
        break;
      default:
        eventPulse = .18;
    }
  }

  void update(double dt, Match2DState state) {
    eventTimer = max(0, eventTimer - dt);
    eventPulse = max(0, eventPulse - dt * .8);
    if (eventTimer <= 0) {
      activeEvent = null;
      eventLabel = null;
    }
    final minutePressure = state.minute >= 80 ? .14 : state.minute >= 70 ? .07 : 0;
    final scorePressure = (state.homeGoals - state.awayGoals).abs() >= 1 ? .05 : .09;
    targetIntensity = (.40 + minutePressure + scorePressure + eventPulse * .38).clamp(.22, 1.0);
    intensity += (targetIntensity - intensity) * (1 - exp(-dt * 2.5));
    homeEnergy += (.5 - homeEnergy) * dt * .035;
    awayEnergy += (.5 - awayEnergy) * dt * .035;
  }

  Match2DTeam? _teamForPlayer(String id, Match2DState state) {
    for (final p in state.players) if (p.id == id) return p.team;
    return null;
  }

  String _label(Match2DEventType type) {
    switch (type) {
      case Match2DEventType.goal: return 'GOAL';
      case Match2DEventType.shot: return 'CHANCE';
      case Match2DEventType.save: return 'SAVE';
      case Match2DEventType.corner: return 'CORNER';
      case Match2DEventType.card: return 'CARD';
      case Match2DEventType.foul: return 'FOUL';
      case Match2DEventType.halftime: return 'HALF TIME';
      case Match2DEventType.fulltime: return 'FULL TIME';
      default: return 'EVENT';
    }
  }
}

class StadiumAtmosphereComponent extends PositionComponent {
  StadiumAtmosphereComponent(this.director) : super(priority: -5);
  final StadiumAtmosphereDirector director;

  @override
  void render(Canvas canvas) {
    final pulse = director.eventPulse;
    final intensity = director.intensity;
    final vignette = Paint()..shader = RadialGradient(
      colors: [Colors.transparent, Colors.black.withValues(alpha: .10 + intensity * .18)],
      stops: const [0.45, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), vignette);

    if (pulse > .02) {
      final glow = Paint()..color = Colors.white.withValues(alpha: pulse * .09);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), glow);
    }

    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: .035 + intensity * .035);
    for (var i = 0; i < 5; i++) {
      final y = size.y * (.12 + i * .19);
      final path = Path();
      for (var x = 0.0; x <= size.x; x += 18) {
        final yy = y + sin(x * .025 + director.intensity * 4 + i) * (2 + pulse * 5);
        if (x == 0) path.moveTo(x, yy); else path.lineTo(x, yy);
      }
      canvas.drawPath(path, wavePaint);
    }
  }
}
