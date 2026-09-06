import 'package:fpg/models/player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/attacking_run.dart';
import 'package:fpg/models/match_2d.dart';
import 'package:fpg/models/player_role.dart';
import 'package:fpg/models/team_play_style.dart';
import 'package:fpg/simulation/attacking_run_engine.dart';

void main() {
  test('striker chooses depth run when space is available', () {
    const engine = AttackingRunEngine();
    final striker = Match2DPlayer(id: 's', name: 'S', position: PlayerPosition.striker, role: PlayerRole.poacher, team: Match2DTeam.home, x: 72, y: 50, shirtNumber: 9, overall: 80);
    final owner = Match2DPlayer(id: 'm', name: 'M', position: PlayerPosition.midfielder, team: Match2DTeam.home, x: 58, y: 50, shirtNumber: 8, overall: 80);
    final opponent = Match2DPlayer(id: 'd', name: 'D', position: PlayerPosition.defender, team: Match2DTeam.away, x: 82, y: 50, shirtNumber: 4, overall: 75);
    final result = engine.choose(player: striker, owner: owner, teammates: [owner], opponents: [opponent], phase: Match2DPhase.finalThird, style: TeamPlayStyle.counter, urgency: 1.2, forwardRun: 1.2, width: 1, direction: 1, forwardSpace: 18);
    expect(result.type, AttackingRunType.depth);
    expect(result.targetX, greaterThan(striker.x));
  });
}
