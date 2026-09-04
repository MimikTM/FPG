import 'package:fpg/models/player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/match_2d.dart';
import 'package:fpg/simulation/goalkeeper_engine.dart';

void main() {
  test('goalkeeper assessment returns bounded save and positioning values', () {
    final keeper = Match2DPlayer(
      id: 'gk', name: 'GK', position: PlayerPosition.goalkeeper,
      team: Match2DTeam.away, x: 96, y: 50, shirtNumber: 1, overall: 82,
      defending: 80, physical: 75, pace: 70,
    );
    final shooter = Match2DPlayer(
      id: 'st', name: 'ST', position: PlayerPosition.striker,
      team: Match2DTeam.home, x: 84, y: 50, shirtNumber: 9, overall: 80,
      shooting: 82,
    );
    final state = Match2DState(players: [keeper, shooter]);
    final a = const GoalkeeperEngine().assess(state: state, goalkeeper: keeper, shooter: shooter);
    expect(a.positioning, inInclusiveRange(0, 1));
    expect(a.saveProbability, inInclusiveRange(.08, .72));
    expect(a.oneOnOneRisk, inInclusiveRange(0, 1));
  });
}
