import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/match_2d.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/models/player_role.dart';
import 'package:fpg/simulation/match_contact_engine.dart';

Match2DPlayer p(String id, {int overall = 70, int physical = 70, int stamina = 100}) => Match2DPlayer(
  id: id, name: id, position: PlayerPosition.midfielder, role: PlayerRole.boxToBox,
  team: Match2DTeam.home, x: 50, y: 50, shirtNumber: 8, overall: overall,
  physical: physical, stamina: stamina,
);

void main() {
  test('first touch remains bounded and context sensitive', () {
    final engine = MatchContactEngine(random: Random(7));
    final calm = engine.firstTouch(receiver: p('a', overall: 85), ballSpeed: 6, pressure: 2, ballHeight: 0);
    final rushed = engine.firstTouch(receiver: p('b', overall: 45, stamina: 55), ballSpeed: 24, pressure: 18, ballHeight: 5);
    expect(calm.retention, inInclusiveRange(0.08, 0.85));
    expect(rushed.retention, inInclusiveRange(0.08, 0.85));
  });

  test('physical duel produces a valid outcome without touching match result', () {
    final engine = MatchContactEngine(random: Random(11));
    final result = engine.shoulderToShoulder(first: p('a', physical: 90), second: p('b', physical: 50), speed: 12, space: 5);
    expect(PhysicalDuelOutcome.values, contains(result.outcome));
    expect(result.foulRisk, inInclusiveRange(.05, .65));
  });
}
