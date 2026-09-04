import 'package:flutter_test/flutter_test.dart';
import 'dart:math';
import 'package:fpg/simulation/chance_creation_engine.dart';
import 'package:fpg/models/match_2d.dart';
import 'package:fpg/models/player.dart';

void main() {
  test('closer and less pressured chance has higher quality', () {
    final shooter = Match2DPlayer(id:'s', name:'S', position:PlayerPosition.striker, team:Match2DTeam.home, x:82, y:50, shirtNumber:9, overall:85, shooting:88, passing:70, dribbling:82, physical:75, stamina:95);
    final defender = Match2DPlayer(id:'d', name:'D', position:PlayerPosition.defender, team:Match2DTeam.away, x:30, y:20, shirtNumber:4, overall:70, defending:70);
    final state = Match2DState(players:[shooter, defender], ballOwnerId:'s');
    final a = ChanceCreationEngine(random: Random(1)).assess(state:state, shooter:shooter);
    expect(a.xG, greaterThan(.1));
    expect(a.pressure, equals(0));
  });
}
