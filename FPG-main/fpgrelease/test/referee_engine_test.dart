import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/match_2d.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/simulation/referee_engine.dart';
import 'package:fpg/models/player_role.dart';

Match2DPlayer p(String id, Match2DTeam team, {bool yellow = false, int defending = 60, int physical = 60}) => Match2DPlayer(
  id: id, name: id, position: PlayerPosition.defender, role: PlayerRole.coverDefender,
  team: team, x: 50, y: 50, shirtNumber: 2, overall: 70, pace: 70,
  shooting: 50, passing: 55, dribbling: 60, defending: defending, physical: physical,
  yellowCard: yellow,
);

void main() {
  test('clean challenge can remain play-on', () {
    final e = RefereeEngine(random: Random(1));
    final d = e.resolveChallenge(defender: p('D', Match2DTeam.home, defending: 95), attacker: p('A', Match2DTeam.away), distance: 10, speed: 1, inPenaltyArea: false, minute: 20);
    expect(d.isFoul, isFalse);
    expect(d.restart, RefereeRestart.playOn);
  });

  test('high-risk challenge can produce a foul/restart', () {
    final e = RefereeEngine(random: Random(4));
    final d = e.resolveChallenge(defender: p('D', Match2DTeam.home, defending: 25, physical: 90), attacker: p('A', Match2DTeam.away), distance: 1, speed: 11, inPenaltyArea: true, minute: 88);
    expect(d.isFoul, isTrue);
    expect(d.restart, anyOf(RefereeRestart.penalty, RefereeRestart.advantage));
  });

  test('second yellow is possible but only after a foul', () {
    final e = RefereeEngine(random: Random(8));
    final d = e.resolveChallenge(defender: p('D', Match2DTeam.home, yellow: true, defending: 30, physical: 85), attacker: p('A', Match2DTeam.away), distance: 1, speed: 10, inPenaltyArea: false, minute: 82);
    expect(d.isFoul, isTrue);
  });
}
