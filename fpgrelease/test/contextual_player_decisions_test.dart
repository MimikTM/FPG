import 'package:fpg/models/player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/match_2d.dart';
import 'package:fpg/models/match_player_decision.dart';

void main() {
  Match2DPlayer player({
    PlayerPosition position = PlayerPosition.midfielder,
    int shooting = 70,
    int passing = 70,
    int dribbling = 70,
    int pace = 70,
  }) => Match2DPlayer(
    id: 'p', name: 'Player', position: position, team: Match2DTeam.home,
    x: 78, y: 50, shirtNumber: 10, overall: 80,
    shooting: shooting, passing: passing, dribbling: dribbling, pace: pace,
  );

  test('dangerous space makes shooting a viable contextual decision', () {
    final p = player(position: PlayerPosition.striker, shooting: 90);
    final d = const MatchPlayerDecisionEngine().choose(MatchPlayerDecisionContext(
      player: p, nearestOpponent: null, bestTeammate: null,
      pressure: 12, forwardSpace: 18, distanceToGoal: 16,
      scoreUrgency: .8, transitionUrgency: .8, inFinalThird: true,
      losing: false, leading: false, underHeavyPressure: false,
    ));
    expect(d.action, MatchPlayerDecisionAction.shoot);
  });

  test('heavy pressure favors safer circulation over dribble', () {
    final p = player(dribbling: 45, passing: 85);
    final d = const MatchPlayerDecisionEngine().choose(MatchPlayerDecisionContext(
      player: p, nearestOpponent: null, bestTeammate: null,
      pressure: 3, forwardSpace: 4, distanceToGoal: 55,
      scoreUrgency: .7, transitionUrgency: .8, inFinalThird: false,
      losing: false, leading: true, underHeavyPressure: true,
    ));
    expect(<MatchPlayerDecisionAction>{MatchPlayerDecisionAction.pass, MatchPlayerDecisionAction.recycle}, contains(d.action));
  });
}
