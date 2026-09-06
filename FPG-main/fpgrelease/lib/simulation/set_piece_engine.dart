import '../models/player.dart';
import 'dart:math';
import '../models/match_2d.dart';
import '../models/player_role.dart';

/// Resolves restart intent without owning the official match result.
/// It produces a deterministic football outcome from the players, roles,
/// distance and team style; Match2DEngine remains authoritative for score/save.
class SetPieceEngine {
  final Random random;
  SetPieceEngine({Random? random}) : random = random ?? Random();

  SetPiecePlan corner({required Match2DPlayer taker, required List<Match2DPlayer> attackers, required List<Match2DPlayer> defenders, required bool attackingHome}) {
    final target = _bestAerial(attackers);
    final marker = _bestAerial(defenders);
    final quality = _deliveryQuality(taker) + (target?.physical ?? 60) * .10;
    final defence = (marker?.defending ?? 60) * .65 + (marker?.physical ?? 60) * .25;
    final margin = quality - defence + random.nextDouble() * 12 - 6;
    if (margin > 18) return SetPiecePlan(kind: SetPieceKind.corner, outcome: SetPieceOutcome.cleanHeader, taker: taker, target: target, defender: marker, x: attackingHome ? 94 : 6, y: target?.y ?? 50);
    if (margin > 5) return SetPiecePlan(kind: SetPieceKind.corner, outcome: SetPieceOutcome.headerChance, taker: taker, target: target, defender: marker, x: attackingHome ? 94 : 6, y: target?.y ?? 50);
    if (margin > -6) return SetPiecePlan(kind: SetPieceKind.corner, outcome: SetPieceOutcome.secondBall, taker: taker, target: target, defender: marker, x: attackingHome ? 88 : 12, y: target?.y ?? 50);
    return SetPiecePlan(kind: SetPieceKind.corner, outcome: SetPieceOutcome.cleared, taker: taker, target: target, defender: marker, x: attackingHome ? 90 : 10, y: 50);
  }

  SetPiecePlan freeKick({required Match2DPlayer taker, required List<Match2DPlayer> attackers, required List<Match2DPlayer> defenders, required bool attackingHome, required double distanceToGoal}) {
    final direct = distanceToGoal < 30 && taker.shooting >= taker.passing;
    final wall = defenders.where((p) => p.active && p.position != PlayerPosition.goalkeeper).length;
    final execution = direct ? taker.shooting * .72 + taker.physical * .08 : taker.passing * .62 + taker.dribbling * .15;
    final pressure = wall * 1.5 + random.nextDouble() * 10;
    final margin = execution - pressure;
    if (direct && distanceToGoal < 25 && margin > 22) return SetPiecePlan(kind: SetPieceKind.freeKick, outcome: SetPieceOutcome.directShot, taker: taker, target: taker, x: attackingHome ? 75 : 25, y: 50);
    final target = _bestAerial(attackers);
    if (margin > 4 && target != null) return SetPiecePlan(kind: SetPieceKind.freeKick, outcome: SetPieceOutcome.crossChance, taker: taker, target: target, x: attackingHome ? 72 : 28, y: target.y);
    return SetPiecePlan(kind: SetPieceKind.freeKick, outcome: SetPieceOutcome.recycled, taker: taker, target: attackers.isEmpty ? taker : attackers.first, x: attackingHome ? 65 : 35, y: 50);
  }


  SetPiecePlan penalty({required Match2DPlayer taker, required List<Match2DPlayer> defenders, required bool attackingHome}) {
    final pressure = defenders.where((p) => p.active && p.position == PlayerPosition.goalkeeper).fold<double>(0, (v, g) => v + g.overall * .45);
    final quality = taker.shooting * .72 + taker.overall * .20 - taker.stamina * .05;
    final margin = quality - pressure + random.nextDouble() * 12 - 6;
    return SetPiecePlan(kind: SetPieceKind.penalty, outcome: margin > 20 ? SetPieceOutcome.directShot : SetPieceOutcome.headerChance, taker: taker, target: taker, x: attackingHome ? 92 : 8, y: 50);
  }

  Match2DPlayer? _bestAerial(List<Match2DPlayer> players) {
    if (players.isEmpty) return null;
    return players.reduce((a, b) => _aerialScore(a) >= _aerialScore(b) ? a : b);
  }

  double _aerialScore(Match2DPlayer p) => p.physical * .55 + p.overall * .25 + (p.role == PlayerRole.targetForward ? 12 : 0) + (p.role == PlayerRole.poacher ? 5 : 0);
  double _deliveryQuality(Match2DPlayer p) => p.passing * .65 + p.shooting * .15 + p.overall * .15;
}

enum SetPieceKind { corner, freeKick, penalty }
enum SetPieceOutcome { directShot, crossChance, cleanHeader, headerChance, secondBall, cleared, recycled }

class SetPiecePlan {
  final SetPieceKind kind;
  final SetPieceOutcome outcome;
  final Match2DPlayer taker;
  final Match2DPlayer? target;
  final Match2DPlayer? defender;
  final double x;
  final double y;
  const SetPiecePlan({required this.kind, required this.outcome, required this.taker, this.target, this.defender, required this.x, required this.y});
}
