import 'package:fpg/models/player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/match_2d.dart';
import 'package:fpg/models/match_transition.dart';

void main() {
  test('transition profile differentiates high press and low block', () {
    final hp = MatchTransitionProfile.fromStyle('high_press', MatchTransitionPhase.counterPress);
    final lb = MatchTransitionProfile.fromStyle('low_block', MatchTransitionPhase.settledDefence);
    expect(hp.lineHeight, greaterThan(lb.lineHeight));
    expect(hp.counterPress, greaterThan(lb.counterPress));
    expect(lb.compactness, greaterThan(hp.compactness));
  });

  test('phase detects retreat when opponent has the ball', () {
    final a = Match2DPlayer(id: 'a', name: 'A', position: PlayerPosition.defender, team: Match2DTeam.home, x: 30, y: 50, shirtNumber: 4, overall: 70);
    final b = Match2DPlayer(id: 'b', name: 'B', position: PlayerPosition.striker, team: Match2DTeam.away, x: 70, y: 50, shirtNumber: 9, overall: 70);
    final state = Match2DState(players: [a, b], ballOwnerId: 'b');
    expect(MatchTransitionProfile.phaseFor(state: state, team: Match2DTeam.home, owner: b, previousOwner: null), MatchTransitionPhase.retreat);
  });
}
