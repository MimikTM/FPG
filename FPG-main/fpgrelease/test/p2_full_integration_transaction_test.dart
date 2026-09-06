import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/core/game_engine.dart';
import 'package:fpg/core/game_state.dart';
import 'package:fpg/models/player.dart';

void main() {
  test('P2.0 interactive fixture is transactional: preview does not update table, commit does', () {
    final engine = GameEngine(state: GameState(year: 2026, month: 7, day: 24, season: 2026));
    final club = engine.clubs.firstWhere((c) => c.leagueId == 'pol_ek');
    final fixture = engine.fixtures.firstWhere((f) =>
        !f.played &&
        (f.homeClubId == club.id || f.awayClubId == club.id));

    engine.createPlayer(
      firstName: 'Test', lastName: 'Player', nationality: 'PL', age: 19,
      height: 180, position: PlayerPosition.striker,
      pace: 75, shooting: 75, passing: 65, dribbling: 75,
      defending: 40, physical: 70,
    );
    engine.careerPlayer!.clubId = club.id;
    engine.careerWorldBridge.pushCareerState(engine.careerPlayer!);

    // The transaction guard is date-aware: commit the fixture on its real
    // calendar day, as the Match 2D screen does.
    engine.state.year = fixture.year;
    engine.state.month = fixture.month;
    engine.state.day = fixture.day;

    final beforePlayed = engine.leagueEngine.standings.values
        .fold<int>(0, (sum, s) => sum + s.played);
    final preview = engine.previewFixture(fixture);
    final afterPreviewPlayed = engine.leagueEngine.standings.values
        .fold<int>(0, (sum, s) => sum + s.played);

    expect(fixture.played, isFalse);
    expect(beforePlayed, afterPreviewPlayed);
    expect(preview.homeGoals, greaterThanOrEqualTo(0));
    expect(preview.awayGoals, greaterThanOrEqualTo(0));

    engine.reconcileInteractiveFixtureResult(
      fixture: fixture,
      finalHomeGoals: 2,
      finalAwayGoals: 1,
    );

    final afterCommitPlayed = engine.leagueEngine.standings.values
        .fold<int>(0, (sum, s) => sum + s.played);
    expect(fixture.played, isTrue);
    expect(fixture.homeGoals, 2);
    expect(fixture.awayGoals, 1);
    expect(afterCommitPlayed, beforePlayed + 2);

    // Replaying the same finalization is idempotent: the table cannot gain
    // another match and career appearance cannot be duplicated.
    final appearances = engine.careerPlayer!.careerAppearances;
    engine.reconcileInteractiveFixtureResult(
      fixture: fixture,
      finalHomeGoals: 2,
      finalAwayGoals: 1,
    );
    final afterSecondCommitPlayed = engine.leagueEngine.standings.values
        .fold<int>(0, (sum, s) => sum + s.played);

    expect(afterSecondCommitPlayed, afterCommitPlayed);
    expect(engine.careerPlayer!.careerAppearances, appearances);
    expect(engine.validateLeagueIntegrity(), isTrue);
  });

test('P2.0 daily flow pauses on the career fixture and cannot skip match day', () {
  final engine = GameEngine(
    state: GameState(year: 2026, month: 7, day: 24, season: 2026),
  );
  final club = engine.clubs.firstWhere((c) => c.leagueId == 'pol_ek');

  engine.createPlayer(
    firstName: 'Flow', lastName: 'Tester', nationality: 'PL', age: 19,
    height: 180, position: PlayerPosition.striker,
    pace: 75, shooting: 75, passing: 65, dribbling: 75,
    defending: 40, physical: 70,
  );
  engine.assignPlayerToClub(club.id);

  final fixture = engine.fixtures.firstWhere((f) =>
      !f.played && (f.homeClubId == club.id || f.awayClubId == club.id));
  final fixtureDate = DateTime(fixture.year, fixture.month, fixture.day);
  final before = fixtureDate.subtract(const Duration(days: 1));
  engine.state.year = before.year;
  engine.state.month = before.month;
  engine.state.day = before.day;

  final report = engine.advanceDay();

  expect(engine.state.year, fixture.year);
  expect(engine.state.month, fixture.month);
  expect(engine.state.day, fixture.day);
  expect(fixture.played, isFalse);
  expect(engine.careerHasMatchToday, isTrue);
  expect(report.phases.last.name, 'awaitingCareerMatch');
  expect(() => engine.advanceDay(), throwsStateError);

  engine.reconcileInteractiveFixtureResult(
    fixture: fixture,
    finalHomeGoals: 1,
    finalAwayGoals: 0,
  );
  expect(fixture.played, isTrue);
  expect(engine.careerHasMatchToday, isFalse);

  final completed = engine.finalizeCareerMatchDay();
  expect(completed.careerMatchesCompleted, 1);
  expect(engine.validateLeagueIntegrity(), isTrue);
});

}
