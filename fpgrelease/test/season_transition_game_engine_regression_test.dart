import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/core/game_engine.dart';
import 'package:fpg/core/game_state.dart';
import 'package:fpg/models/player.dart';

void main() {
  test('GameEngine generates the next season schedule after the June 30 rollover', () {
    final engine = GameEngine(
      state: GameState(year: 2027, month: 6, day: 29, season: 2026),
    );
    final club = engine.clubs.firstWhere((c) => c.leagueId == 'pol_ek');

    engine.createPlayer(
      firstName: 'Season',
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

    // Finish the current league table through the normal non-interactive
    // fixture path. Interactive reconciliation is intentionally restricted to
    // the player's actual calendar day.
    for (final fixture in engine.fixtures.where((f) => !f.played).toList()) {
      engine.playFixture(fixture);
    }

    engine.state.year = 2027;
    engine.state.month = 6;
    engine.state.day = 30;
    engine.state.season = 2026;

    final report = engine.advanceDay();

    expect(report.seasonAdvanced, isTrue);
    expect(engine.state.dateString, '01.07.2027');
    expect(engine.state.season, 2027);
    expect(engine.fixtures, isNotEmpty);
    expect(
      engine.fixtures.every((f) => f.year == 2027 || f.year == 2028),
      isTrue,
    );
    expect(
      engine.fixtures.any((f) => f.year == 2026),
      isFalse,
    );
    expect(engine.leagueEngine.standings.values.every((s) => s.played == 0), isTrue);
    expect(engine.validateLeagueIntegrity(), isTrue);
  });
}
