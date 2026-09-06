import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/match_2d.dart';
import 'match_presentation_director.dart';

/// Final presentation layer for the Matchday camera.
/// It coordinates phase-specific framing without touching match simulation.
class MatchCinematicDirector {
  double _time = 0;
  double _fade = 0;
  MatchPresentationPhase _phase = MatchPresentationPhase.intro;
  Vector2 cameraOffset = Vector2.zero();
  double cameraZoom = 1.0;
  bool hasCinematicFrame = false;
  String label = '';

  void update(double dt, MatchPresentationDirector presentation, Match2DState state, Vector2 size) {
    _time += dt;
    _phase = presentation.phase;
    final event = presentation.activeEvent;
    final terminal = _phase == MatchPresentationPhase.fulltime || _phase == MatchPresentationPhase.postMatch;
    hasCinematicFrame = _phase != MatchPresentationPhase.live && _phase != MatchPresentationPhase.secondHalf;

    double targetFade = hasCinematicFrame ? .72 : 0.0;
    if (event == Match2DEventType.goal) targetFade = .34;
    _fade += (targetFade - _fade) * (1 - exp(-dt * 5.0));

    switch (_phase) {
      case MatchPresentationPhase.intro:
        label = 'MATCHDAY';
        cameraZoom = 0.88 + sin(_time * 1.1) * .018;
        cameraOffset = Vector2(0, size.y * -.045);
        break;
      case MatchPresentationPhase.lineup:
        label = 'STARTING XI';
        cameraZoom = 1.03;
        cameraOffset = Vector2(0, size.y * .02);
        break;
      case MatchPresentationPhase.halftime:
        label = 'HALF TIME';
        cameraZoom = .93;
        cameraOffset = Vector2(0, size.y * -.015);
        break;
      case MatchPresentationPhase.fulltime:
        label = state.homeGoals == state.awayGoals ? 'FULL TIME • DRAW' : 'FULL TIME';
        cameraZoom = .91;
        cameraOffset = Vector2(0, size.y * -.035);
        break;
      case MatchPresentationPhase.postMatch:
        label = 'MATCH REPORT';
        cameraZoom = .94;
        cameraOffset = Vector2.zero();
        break;
      case MatchPresentationPhase.live:
      case MatchPresentationPhase.secondHalf:
        label = event == null ? 'LIVE' : event.name.toUpperCase();
        cameraZoom = 1.0;
        cameraOffset = Vector2.zero();
        break;
    }
    if (terminal && event == Match2DEventType.goal) label = 'FULL TIME';
  }

  double get fade => _fade;
}

class CinematicFrame extends PositionComponent {
  CinematicFrame(this.director) : super(priority: 1000);
  final MatchCinematicDirector director;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final fade = director.fade;
    if (fade <= .01) return;
    final h = size.y;
    final bar = min(46.0, h * .075);
    final paint = Paint()..color = Colors.black.withValues(alpha: fade);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, bar), paint);
    canvas.drawRect(Rect.fromLTWH(0, h - bar, size.x, bar), paint);

    final tp = TextPainter(
      text: TextSpan(text: director.label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.2)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.x - tp.width) / 2, h - bar + 15));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    position = Vector2.zero();
  }
}
