import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/core/game_engine.dart';
import 'package:fpg/core/game_state.dart';
import 'package:fpg/models/player.dart';

void main() {
  test('finalized career match clears transient transaction state', () {
    final engine = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );
    final club = engine.clubs.firstWhere((c) => c.leagueId == 'pol_ek');

    engine.createPlayer(
      firstName: 'Finalize',
      lastName: 'Tester',
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

    while (!engine.careerHasMatchToday) {
      engine.advanceSimulationDay();
    }

    final fixture = engine.nextCareerFixture;
    expect(fixture, isNotNull);
    final preview = engine.previewFixture(fixture!);
    engine.reconcileInteractiveFixtureResult(
      fixture: fixture,
      finalHomeGoals: preview.homeGoals,
      finalAwayGoals: preview.awayGoals,
    );

    expect(engine.careerMatchSnapshot['today'], isTrue);
    engine.finalizeCareerMatchDay();

    // A SAVE taken now must not contain a still-pending match transaction.
    expect(engine.careerMatchSnapshot['today'], isFalse);
    expect(engine.careerHasMatchToday, isFalse);

    // A second finalize must be rejected rather than applying consequences or
    // the world tick twice.
    expect(
      () => engine.finalizeCareerMatchDay(),
      throwsStateError,
    );
  });
}
