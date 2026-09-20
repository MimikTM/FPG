import 'dart:math';
import '../models/match_2d.dart';
import '../models/player_role.dart';
import '../models/team_play_style.dart';
import '../models/attacking_run.dart';

/// Decides where off-ball attackers should move. It is deliberately target-
/// based: PlayerMovementEngine still owns acceleration and final movement.
class AttackingRunEngine {
  const AttackingRunEngine();

  AttackingRunDecision choose({
    required Match2DPlayer player,
    required Match2DPlayer owner,
    required List<Match2DPlayer> teammates,
    required List<Match2DPlayer> opponents,
    required Match2DPhase phase,
    required TeamPlayStyle style,
    required double urgency,
    required double forwardRun,
    required double width,
    required double direction,
    required double forwardSpace,
  }) {
    final opponentLine = _nearestForwardOpponent(player, opponents, direction);
    final gap = opponentLine == null ? 18.0 : max(3.0, (opponentLine.x - player.x) * direction);
    final openLane = _bestLane(player, opponents, direction);
    var type = AttackingRunType.support;
    var x = player.homeX;
    var y = player.homeY;
    var intensity = (.72 + urgency * .35).clamp(.55, 1.45);

    final wide = (player.homeY - 50).abs() > 14;
    final central = (player.homeY - 50).abs() < 11;
    final attackingStyle = style == TeamPlayStyle.direct || style == TeamPlayStyle.counter;
    final pressStyle = style == TeamPlayStyle.highPress;

    switch (player.role) {
      case PlayerRole.targetForward:
      case PlayerRole.poacher:
      case PlayerRole.pressingForward:
        if (forwardSpace > 10 && gap > 7) {
          type = AttackingRunType.depth;
          x += direction * (4.0 + forwardRun * 4.0);
          y += (owner.y - y) * .10;
          intensity *= 1.08;
        } else {
          type = AttackingRunType.channel;
          x += direction * 2.5;
          y = 50 + (owner.y - 50) * .55;
        }
        break;
      case PlayerRole.wideWinger:
      case PlayerRole.invertedWinger:
      case PlayerRole.insideForward:
        if (style == TeamPlayStyle.wingPlay && wide) {
          type = AttackingRunType.channel;
          x += direction * (3.0 + forwardRun * 2.5);
          y += (player.homeY - 50) * .10;
        } else if (style == TeamPlayStyle.possession && central) {
          type = AttackingRunType.support;
          x += direction * 2.0;
          y += (50 - y) * .18;
        } else {
          type = AttackingRunType.channel;
          x += direction * (2.5 + forwardRun * 2.0);
          y += (openLane - y) * .18;
        }
        break;
      case PlayerRole.attackingFullBack:
        if (gap > 8) {
          type = AttackingRunType.overlap;
          x += direction * (5.0 + forwardRun * 3.0);
          y += (player.homeY - 50) * .05;
          intensity *= 1.10;
        } else {
          type = AttackingRunType.underlap;
          x += direction * 2.5;
          y += (50 - y) * .16;
        }
        break;
      case PlayerRole.boxToBox:
      case PlayerRole.playmaker:
        if (phase == Match2DPhase.finalThird && forwardSpace > 12) {
          type = AttackingRunType.depth;
          x += direction * (2.5 + forwardRun * 2.2);
          y += (owner.y - y) * .12;
        } else {
          type = AttackingRunType.support;
          x += direction * 1.8;
          y += (owner.y - y) * .18;
        }
        break;
      case PlayerRole.falseNine:
        type = AttackingRunType.decoy;
        x -= direction * 3.0;
        y += (owner.y - y) * .12;
        break;
      case PlayerRole.ballPlayingDefender:
      case PlayerRole.stopper:
      case PlayerRole.coverDefender:
      case PlayerRole.anchor:
      case PlayerRole.fullBack:
      case PlayerRole.goalkeeper:
        type = AttackingRunType.support;
        x += direction * (player.role == PlayerRole.anchor ? .6 : 1.2);
        y += (owner.y - y) * .10;
        break;
    }

    if (attackingStyle) {
      x += direction * 1.2;
      intensity *= 1.05;
    }
    if (pressStyle && phase != Match2DPhase.buildUp) intensity *= 1.04;
    if (style == TeamPlayStyle.lowBlock) intensity *= .88;
    x += direction * (width - 1.0) * 1.2 * (wide ? .4 : .15);

    final separation = _nearestTeammateDistance(player, teammates, x, y);
    if (separation < 5.0 && player.role != PlayerRole.goalkeeper) {
      y += player.homeY < 50 ? -2.5 : 2.5;
    }
    final danger = max(0.0, forwardSpace) * .45 + gap * .25 + intensity * 2.0;
    return AttackingRunDecision(
      type: type,
      targetX: x.clamp(3.0, 97.0).toDouble(),
      targetY: y.clamp(4.0, 96.0).toDouble(),
      intensity: intensity.clamp(.45, 1.55),
      separation: danger,
      role: player.role,
    );
  }

  double _bestLane(Match2DPlayer player, List<Match2DPlayer> opponents, double direction) {
    final candidates = <double>[player.y, player.y < 50 ? 35 : 65, 50];
    candidates.sort((a, b) => _lanePressure(a, opponents).compareTo(_lanePressure(b, opponents)));
    return candidates.first;
  }

  double _lanePressure(double y, List<Match2DPlayer> opponents) => opponents.fold<double>(0, (sum, p) {
    final d = (p.y - y).abs();
    return sum + (d < 9 ? (9 - d) : 0);
  });

  Match2DPlayer? _nearestForwardOpponent(Match2DPlayer player, List<Match2DPlayer> opponents, double direction) {
    Match2DPlayer? best;
    var bestD = double.infinity;
    for (final p in opponents) {
      final forward = (p.x - player.x) * direction;
      if (forward < -2) continue;
      final d = (p.x - player.x).abs() + (p.y - player.y).abs();
      if (d < bestD) { bestD = d; best = p; }
    }
    return best;
  }

  double _nearestTeammateDistance(Match2DPlayer player, List<Match2DPlayer> teammates, double x, double y) {
    var best = double.infinity;
    for (final p in teammates) {
      if (p.id == player.id) continue;
      best = min(best, sqrt(pow(p.x - x, 2) + pow(p.y - y, 2)));
    }
    return best;
  }
}
