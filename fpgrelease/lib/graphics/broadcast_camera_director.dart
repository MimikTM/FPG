import 'dart:math';
import 'package:flame/components.dart';
import '../models/match_2d.dart';

/// Presentation-only broadcast camera director.
///
/// Match2DEngine remains authoritative. This class only decides where the
/// Flame camera should look and how tightly it should frame the action.
class BroadcastCameraDirector {
  Vector2 target = Vector2.zero();
  double zoom = 1.0;
  double _timer = 0;
  Match2DEventType? _event;
  String? _focusPlayerId;

  void reset(Vector2 initialTarget) {
    target = initialTarget.clone();
    zoom = 1.0;
    _timer = 0;
    _event = null;
    _focusPlayerId = null;
  }

  void onEvent(Match2DEvent event) {
    _event = event.type;
    _focusPlayerId = event.playerId;
    switch (event.type) {
      case Match2DEventType.goal:
        _timer = 3.2;
        zoom = 1.08;
        break;
      case Match2DEventType.shot:
      case Match2DEventType.save:
        _timer = .85;
        zoom = 1.055;
        break;
      case Match2DEventType.foul:
      case Match2DEventType.card:
      case Match2DEventType.injury:
        _timer = 1.15;
        zoom = 1.035;
        break;
      case Match2DEventType.substitution:
        _timer = 2.25;
        zoom = 1.04;
        break;
      case Match2DEventType.halftime:
      case Match2DEventType.fulltime:
        _timer = 1.8;
        zoom = 1.0;
        break;
      default:
        // Keep ordinary play wide and fluid.
        break;
    }
  }

  void update(double dt, Vector2 ballTarget, Map<String, Vector2> playerTargets) {
    _timer = max(0, _timer - dt);

    final playerTarget = _focusPlayerId == null ? null : playerTargets[_focusPlayerId];
    final focusTarget = playerTarget ?? ballTarget;
    final desired = _timer > 0 ? focusTarget : ballTarget;
    final speed = _timer > 0 ? 7.0 : 3.2;
    final lerp = 1 - exp(-dt * speed);
    target += (desired - target) * lerp;

    final desiredZoom = _timer <= 0
        ? 1.0
        : (_event == Match2DEventType.goal ? 1.08 :
            (_event == Match2DEventType.halftime || _event == Match2DEventType.fulltime ? 1.0 : 1.05));
    zoom += (desiredZoom - zoom) * (1 - exp(-dt * 5.5));

    if (_timer <= 0) {
      _event = null;
      _focusPlayerId = null;
    }
  }
}
