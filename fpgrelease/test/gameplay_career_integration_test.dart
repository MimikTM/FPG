import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/simulation/gameplay_career_integration.dart';
import 'package:fpg/simulation/match_2d_engine.dart';

void main() {
  test('gameplay career adapter rejects unfinished matches', () {
    final player = Player(
      id: 'p1',
      name: 'Test',
      age: 24,
      position: PlayerPosition.striker,
      overall: 70,
      potential: 80,
    );
    Player clone(String id, String name) => Player(
      id: id,
      name: name,
      age: player.age,
      position: player.position,
      overall: player.overall,
      potential: player.potential,
    );
    final engine = Match2DEngine();
    engine.create(
      home: List.generate(11, (i) => clone('h$i', 'H$i')),
      away: List.generate(11, (i) => clone('a$i', 'A$i')),
      gameplayResultAuthority: true,
    );

    expect(
      () => GameplayCareerIntegration.toMatchResult(
        engine: engine, homeClubId: 'home', awayClubId: 'away',
      ),
      throwsStateError,
    );
  });
}
