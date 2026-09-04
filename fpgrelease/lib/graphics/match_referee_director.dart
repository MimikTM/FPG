import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/match_2d.dart';

/// Presentation-only referee director.
/// Match2DEngine remains authoritative for fouls, cards and match time.
class MatchRefereeDirector {
  Vector2 position = Vector2.zero();
  Vector2 target = Vector2.zero();
  Match2DEventType? activeEvent;
  double eventTimer = 0;
  double whistleTimer = 0;
  double gestureTimer = 0;
  bool showCard = false;
  bool redCard = false;
  String? eventLabel;

  void reset(Vector2 initial) {
    position = initial.clone();
    target = initial.clone();
    activeEvent = null;
    eventTimer = 0;
    whistleTimer = 0;
    gestureTimer = 0;
    showCard = false;
    redCard = false;
    eventLabel = null;
  }

  void onEvent(Match2DEvent event, Vector2 eventPosition, Map<String, Vector2> playerPositions) {
    if (event.type != Match2DEventType.foul &&
        event.type != Match2DEventType.card &&
        event.type != Match2DEventType.injury &&
        event.type != Match2DEventType.halftime &&
        event.type != Match2DEventType.fulltime) {
      return;
    }
    activeEvent = event.type;
    eventTimer = event.type == Match2DEventType.card ? 2.1 : 1.45;
    whistleTimer = .48;
    gestureTimer = event.type == Match2DEventType.card ? 1.35 : .75;
    showCard = event.type == Match2DEventType.card;
    redCard = event.description.toUpperCase().contains('CZERWON') ||
        event.description.toUpperCase().contains('RED');
    eventLabel = _label(event.type);
    target = eventPosition.clone();
    // The referee stays close to the action, but offset from the player so the
    // presentation does not cover the incident itself.
    if (playerPositions.isNotEmpty) {
      final anchor = playerPositions[event.playerId] ?? eventPosition;
      final offset = Vector2(18, -12);
      target = anchor + offset;
    }
  }

  void update(double dt, Vector2 ballPosition, Vector2 fieldSize) {
    eventTimer = max(0, eventTimer - dt);
    whistleTimer = max(0, whistleTimer - dt);
    gestureTimer = max(0, gestureTimer - dt);
    if (eventTimer <= 0) {
      activeEvent = null;
      eventLabel = null;
      showCard = false;
      redCard = false;
    }

    if (activeEvent == null) {
      // Referee runs a readable diagonal support line around the ball.
      final offset = Vector2(
        fieldSize.x * .10 * (ballPosition.x < fieldSize.x * .5 ? 1 : -1),
        fieldSize.y * .07 * (ballPosition.y < fieldSize.y * .5 ? 1 : -1),
      );
      target = ballPosition + offset;
    }
    target.x = target.x.clamp(18.0, fieldSize.x - 18.0);
    target.y = target.y.clamp(18.0, fieldSize.y - 18.0);
    final blend = 1 - exp(-dt * (activeEvent == null ? 2.4 : 6.5));
    position += (target - position) * blend;
  }

  bool get isWhistling => whistleTimer > 0;
  bool get isGesturing => gestureTimer > 0;

  String _label(Match2DEventType type) {
    switch (type) {
      case Match2DEventType.foul:
        return 'FOUL';
      case Match2DEventType.card:
        return redCard ? 'RED CARD' : 'YELLOW CARD';
      case Match2DEventType.injury:
        return 'STOPPAGE';
      case Match2DEventType.halftime:
        return 'HALF TIME';
      case Match2DEventType.fulltime:
        return 'FULL TIME';
      default:
        return '';
    }
  }
}

class RefereeComponent extends PositionComponent {
  RefereeComponent(this.director) : super(anchor: Anchor.center);

  final MatchRefereeDirector director;

  @override
  void update(double dt) {
    super.update(dt);
    position = director.position;
  }

  @override
  void render(Canvas canvas) {
    final pulse = director.isWhistling ? 1.22 : 1.0;
    final gesture = director.isGesturing ? sin(director.gestureTimer * 9).abs() : 0.0;
    final body = Paint()..color = const Color(0xFF111827);
    final skin = Paint()..color = const Color(0xFFE0A47A);
    final white = Paint()..color = Colors.white;
    final accent = Paint()..color = director.redCard ? const Color(0xFFE53935) : const Color(0xFFFFD54F);

    canvas.save();
    canvas.scale(pulse, pulse);
    canvas.drawCircle(const Offset(0, -5), 3.0, skin);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-3.4, -1.8, 6.8, 9), const Radius.circular(2)), body);
    canvas.drawLine(const Offset(-1.8, 7), const Offset(-4, 12), body..strokeWidth = 1.6);
    canvas.drawLine(const Offset(1.8, 7), const Offset(4, 12), body..strokeWidth = 1.6);
    canvas.drawLine(const Offset(-3, 1), Offset(-6 - gesture * 5, -3 - gesture * 2), body..strokeWidth = 1.5);
    canvas.drawLine(const Offset(3, 1), Offset(6 + gesture * 5, -3 - gesture * 2), body..strokeWidth = 1.5);
    if (director.isWhistling) {
      canvas.drawCircle(const Offset(5, -6), 1.3, white);
      canvas.drawCircle(const Offset(5, -6), 3.8, white..style = PaintingStyle.stroke..strokeWidth = .8);
    }
    if (director.showCard) {
      canvas.save();
      canvas.translate(7, -10 - gesture * 2);
      canvas.rotate(director.redCard ? -.08 : .08);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-2.8, -4.5, 5.6, 9), const Radius.circular(1)), accent);
      canvas.restore();
    }
    canvas.restore();
  }
}
