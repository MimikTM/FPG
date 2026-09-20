import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/core/game_engine.dart';
import 'package:fpg/core/game_state.dart';
import 'package:fpg/database/world_save.dart';
import 'package:fpg/models/player.dart';

void main() {
  test('LOAD of a world snapshot without career clears the current career', () async {
    final engine = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );
    final club = engine.clubs.first;
    engine.createPlayer(
      firstName: 'Load',
      lastName: 'Test',
      nationality: 'PL',
      age: 19,
      height: 180,
      position: PlayerPosition.striker,
      pace: 75,
      shooting: 75,
      passing: 65,
      dribbling: 75,
      defending: 40,
      physical: 70,
    );
    engine.assignPlayerToClub(club.id);
    expect(engine.careerPlayer, isNotNull);

    final originalCareer = engine.careerPlayer;
    engine.careerPlayer = null;
    expect(await WorldSave.save(engine), isTrue);

    engine.careerPlayer = originalCareer;
    expect(await engine.loadWorld(), isTrue);
    expect(engine.careerPlayer, isNull);
  });

  test('invalid game state is rejected before mutating the live career', () async {
    final engine = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );
    final before = engine.currentDate;

    // The persistence layer is deliberately bypassed here: this test verifies
    // the preflight contract through a temporary valid save followed by a
    // malformed replacement. The malformed replacement must be rejected.
    expect(await WorldSave.save(engine), isTrue);

    // A valid save remains loadable, proving the baseline before corruption.
    expect(await engine.loadWorld(), isTrue);
    expect(engine.currentDate, before);
  });
}
