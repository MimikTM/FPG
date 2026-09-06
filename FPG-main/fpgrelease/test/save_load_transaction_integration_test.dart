import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/core/game_engine.dart';
import 'package:fpg/core/game_state.dart';
import 'package:fpg/models/player.dart';

void main() {
  test('career match transaction persists an exact fixture identity', () {
    final engine = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );
    final club = engine.clubs.firstWhere((c) => c.leagueId == 'pol_ek');

    engine.createPlayer(
      firstName: 'Save',
      lastName: 'Load',
      nationality: 'PL',
      age: 19,
      height: 180,
      position: PlayerPosition.striker,
      pace: 78,
      shooting: 78,
      passing: 65,
      dribbling: 76,
      defending: 40,
      physical: 70,
    );
    engine.assignPlayerToClub(club.id);

    while (!engine.careerHasMatchToday) {
      engine.advanceSimulationDay();
    }

    final fixture = engine.nextCareerFixture!;
    final preview = engine.previewFixture(fixture);
    engine.reconcileInteractiveFixtureResult(
      fixture: fixture,
      finalHomeGoals: preview.homeGoals,
      finalAwayGoals: preview.awayGoals,
    );

    final snapshot = engine.careerMatchSnapshot;
    expect(snapshot['today'], isTrue);
    expect(snapshot['fixtureKey'], isA<String>());
    expect(
      snapshot['fixtureKey'],
      '${fixture.round}|${fixture.homeClubId}|${fixture.awayClubId}|${fixture.year}-${fixture.month}-${fixture.day}',
    );
    expect(fixture.played, isTrue);
    expect(fixture.homeGoals, preview.homeGoals);
    expect(fixture.awayGoals, preview.awayGoals);
  });

  test('a finalized match produces a clean persistence boundary', () {
    final engine = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );
    final club = engine.clubs.firstWhere((c) => c.leagueId == 'pol_ek');

    engine.createPlayer(
      firstName: 'Clean',
      lastName: 'Boundary',
      nationality: 'PL',
      age: 19,
      height: 181,
      position: PlayerPosition.midfielder,
      pace: 72,
      shooting: 65,
      passing: 78,
      dribbling: 73,
      defending: 55,
      physical: 68,
    );
    engine.assignPlayerToClub(club.id);

    while (!engine.careerHasMatchToday) {
      engine.advanceSimulationDay();
    }

    final fixture = engine.nextCareerFixture!;
    final preview = engine.previewFixture(fixture);
    engine.reconcileInteractiveFixtureResult(
      fixture: fixture,
      finalHomeGoals: preview.homeGoals,
      finalAwayGoals: preview.awayGoals,
    );
    engine.finalizeCareerMatchDay();

    final snapshot = engine.careerMatchSnapshot;
    expect(snapshot['today'], isFalse);
    expect(snapshot['fixtureKey'], isNull);
    expect(snapshot['processedFixtureKeys'], isA<List>());
    expect(snapshot['dailyCareerActionConsumed'], isTrue);
  });
}
