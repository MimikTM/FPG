import 'package:fpg/models/player.dart';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/match_2d.dart';
import 'package:fpg/models/player_role.dart';
import 'package:fpg/simulation/set_piece_engine.dart';

Match2DPlayer p(String id, {PlayerRole role = PlayerRole.boxToBox, int passing = 70, int shooting = 70, int physical = 70, int defending = 65}) => Match2DPlayer(id: id, name: id, position: PlayerPosition.midfielder, role: role, team: Match2DTeam.home, x: 70, y: 50, shirtNumber: 8, overall: 75, passing: passing, shooting: shooting, physical: physical, defending: defending);

void main() {
  test('corner selects an aerial target from available attackers', () {
    final e = SetPieceEngine(random: Random(4));
    final plan = e.corner(taker: p('tak', passing: 88), attackers: [p('st', role: PlayerRole.targetForward, physical: 92), p('cm')], defenders: [p('cb', defending: 80)], attackingHome: true);
    expect(plan.kind, SetPieceKind.corner);
    expect(plan.target?.id, 'st');
  });

  test('free kick chooses direct attempt when close and shooter is strong', () {
    final e = SetPieceEngine(random: Random(1));
    final plan = e.freeKick(taker: p('fk', shooting: 95, passing: 72), attackers: [p('st')], defenders: [p('cb', defending: 65)], attackingHome: true, distanceToGoal: 20);
    expect(plan.kind, SetPieceKind.freeKick);
    expect({SetPieceOutcome.directShot, SetPieceOutcome.crossChance, SetPieceOutcome.recycled}, contains(plan.outcome));
  });

  test('penalty is owned by the designated taker', () {
    final e = SetPieceEngine(random: Random(2));
    final plan = e.penalty(taker: p('pen', shooting: 90), defenders: [p('gk')], attackingHome: false);
    expect(plan.kind, SetPieceKind.penalty);
    expect(plan.taker.id, 'pen');
  });
}
