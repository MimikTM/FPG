import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/core/game_engine.dart';
import 'package:fpg/core/game_state.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/models/match_result.dart';
import 'package:fpg/simulation/gameplay_career_integration.dart';
import 'package:fpg/simulation/match_2d_engine.dart';

void main() {
  test('full gameplay authority owns the final score and commits once', () {
    final engine = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );
    final club = engine.clubs.firstWhere((c) => c.leagueId == 'pol_ek');

    engine.createPlayer(
      firstName: 'Gameplay',
      lastName: 'Authority',
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
    final careerPlayer = engine.careerPlayer!;

    final fixture = engine.fixtures.firstWhere((f) =>
        !f.played &&
        (f.homeClubId == club.id || f.awayClubId == club.id));

    engine.state.year = fixture.year;
    engine.state.month = fixture.month;
    engine.state.day = fixture.day;

    final homePlayers =
        engine.players.where((p) => p.clubId == fixture.homeClubId).toList();
    final awayPlayers =
        engine.players.where((p) => p.clubId == fixture.awayClubId).toList();

    final match = Match2DEngine();
    final state = match.create(
      home: homePlayers,
      away: awayPlayers,
      gameplayResultAuthority: true,
      controlledPlayerId: careerPlayer.id,
    );

    expect(state.targetHomeGoals, isNull);
    expect(state.targetAwayGoals, isNull);

    var ticks = 0;
    while (!state.finished && ticks < 120) {
      match.tick();
      ticks++;
    }

    expect(state.finished, isTrue);
    final snapshot = match.gameplayResultSnapshot;
    expect(snapshot.consistent, isTrue);

    final performance = match.performanceForPlayer(careerPlayer.id);
    final result = GameplayCareerIntegration.toMatchResult(
      engine: match,
      homeClubId: fixture.homeClubId,
      awayClubId: fixture.awayClubId,
      playerPerformances:
          performance == null ? const [] : <PlayerMatchPerformance>[performance],
    );

    final playedBefore = engine.leagueEngine.standings.values
        .fold<int>(0, (sum, standing) => sum + standing.played);

    engine.commitGameplayMatchResult(fixture: fixture, result: result);

    final playedAfter = engine.leagueEngine.standings.values
        .fold<int>(0, (sum, standing) => sum + standing.played);

    expect(fixture.played, isTrue);
    expect(fixture.homeGoals, result.homeGoals);
    expect(fixture.awayGoals, result.awayGoals);
    expect(fixture.storedResult?.homeGoals, result.homeGoals);
    expect(fixture.storedResult?.awayGoals, result.awayGoals);
    expect(playedAfter, playedBefore + 2);
    expect(engine.validateLeagueIntegrity(), isTrue);

    final appearances = careerPlayer.careerAppearances;
    engine.commitGameplayMatchResult(fixture: fixture, result: result);

    expect(careerPlayer.careerAppearances, appearances);
    expect(
      engine.leagueEngine.standings.values
          .fold<int>(0, (sum, standing) => sum + standing.played),
      playedAfter,
    );
  });
}
