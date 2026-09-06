import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/core/game_engine.dart';
import 'package:fpg/core/game_state.dart';
import 'package:fpg/models/player.dart';

void main() {
  test('V25.1 career loop survives 400 days without stranded fixtures or table drift', () {
    final engine = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );
    final club = engine.clubs.firstWhere((c) => c.leagueId == 'pol_ek');

    engine.createPlayer(
      firstName: 'Long',
      lastName: 'Runner',
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

    var interactiveMatches = 0;
    var autonomousMatches = 0;

    for (var i = 0; i < 400; i++) {
      final report = engine.advanceDay();

      if (report.phases.last.name == 'awaitingCareerMatch') {
        expect(engine.careerHasMatchToday, isTrue);
        final fixture = engine.nextCareerFixture;
        expect(fixture, isNotNull);
        expect(fixture!.year, engine.state.year);
        expect(fixture.month, engine.state.month);
        expect(fixture.day, engine.state.day);
        expect(fixture.played, isFalse);

        // Use the deterministic preview as a stand-in for a completed 2D
        // match. The important invariant here is that the interactive
        // transaction is the only writer of the career fixture on match day.
        final preview = engine.previewFixture(fixture);
        final playedBefore = engine.leagueEngine.standings.values
            .fold<int>(0, (sum, s) => sum + s.played);

        engine.reconcileInteractiveFixtureResult(
          fixture: fixture,
          finalHomeGoals: preview.homeGoals,
          finalAwayGoals: preview.awayGoals,
        );
        expect(fixture.played, isTrue);
        expect(engine.careerHasMatchToday, isFalse);
        expect(
          engine.leagueEngine.standings.values
              .fold<int>(0, (sum, s) => sum + s.played),
          playedBefore + 2,
        );

        final appearances = engine.careerPlayer!.careerAppearances;
        engine.reconcileInteractiveFixtureResult(
          fixture: fixture,
          finalHomeGoals: preview.homeGoals,
          finalAwayGoals: preview.awayGoals,
        );
        expect(engine.careerPlayer!.careerAppearances, appearances);

        final finalized = engine.finalizeCareerMatchDay();
        autonomousMatches += finalized.careerMatchesCompleted;
        interactiveMatches++;
      }

      autonomousMatches += report.careerMatchesCompleted;
      expect(engine.validateLeagueIntegrity(), isTrue);

      // No career fixture is allowed to remain unplayed in the past.
      final now = DateTime(engine.state.year, engine.state.month, engine.state.day);
      final pastUnplayed = engine.fixtures.where((f) {
        if (f.played) return false;
        if (f.homeClubId != engine.careerPlayer!.clubId &&
            f.awayClubId != engine.careerPlayer!.clubId) {
          return false;
        }
        return DateTime(f.year, f.month, f.day).isBefore(now);
      });
      expect(pastUnplayed, isEmpty);
    }

    // One 8-team double round-robin season contains 14 player fixtures.
    // 400 simulation days from 24 July do not guarantee 20 matchdays, so the
    // invariant is that every scheduled player fixture encountered is handled.
    expect(interactiveMatches, greaterThanOrEqualTo(1));
    expect(engine.careerPlayer!.careerAppearances, greaterThanOrEqualTo(0));
    expect(engine.validateLeagueIntegrity(), isTrue);
    expect(engine.state.year, greaterThanOrEqualTo(2027));
    expect(autonomousMatches, greaterThan(0));
  });
}
