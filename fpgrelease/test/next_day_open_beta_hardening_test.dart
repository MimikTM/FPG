import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/core/game_engine.dart';
import 'package:fpg/core/game_state.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/models/match_2d.dart';
import 'package:fpg/simulation/match_situation_engine.dart';
import 'package:fpg/simulation/match_2d_engine.dart';
import 'package:fpg/simulation/gameplay_career_integration.dart';
import 'package:fpg/models/match_result.dart';

void main() {
  test('calendar JSON cannot create an invalid day that breaks nextDay', () {
    final state = GameState.fromJson({
      'year': 2028, 'month': 2, 'day': 99, 'season': 2028,
      'transferWindowSummer': false, 'transferWindowWinter': false,
    });
    expect(state.dateString, '29.02.2028');
    expect(() => state.nextDay(), returnsNormally);
    expect(state.dateString, '01.03.2028');
  });

  test('next-day career simulation remains callable across a full calendar year', () {
    final engine = GameEngine(state: GameState(year: 2026, month: 7, day: 24, season: 2026));
    final club = engine.clubs.firstWhere((c) => c.leagueId == 'pol_ek');
    engine.createPlayer(
      firstName: 'Open', lastName: 'Beta', nationality: 'PL', age: 19, height: 180,
      position: PlayerPosition.striker, pace: 78, shooting: 76, passing: 66,
      dribbling: 76, defending: 40, physical: 72,
    );
    engine.assignPlayerToClub(club.id);

    for (var i = 0; i < 370; i++) {
      if (engine.careerHasMatchToday) {
        final fixture = engine.nextCareerFixture;
        expect(fixture, isNotNull);
        final activeFixture = fixture!;
        final homePlayers = engine.players
            .where((p) => p.clubId == activeFixture.homeClubId)
            .toList();
        final awayPlayers = engine.players
            .where((p) => p.clubId == activeFixture.awayClubId)
            .toList();
        final match = Match2DEngine();
        final matchState = match.create(
          home: homePlayers,
          away: awayPlayers,
          gameplayResultAuthority: true,
          controlledPlayerId: engine.careerPlayer?.id,
        );

        var ticks = 0;
        while (!matchState.finished && ticks < 240) {
          match.tick();
          ticks++;
        }
        expect(matchState.finished, isTrue);
        expect(match.gameplayResultSnapshot.consistent, isTrue);

        final careerId = engine.careerPlayer?.id;
        final performance = careerId == null
            ? null
            : match.performanceForPlayer(careerId);
        final result = GameplayCareerIntegration.toMatchResult(
          engine: match,
          homeClubId: activeFixture.homeClubId,
          awayClubId: activeFixture.awayClubId,
          playerPerformances: performance == null
              ? const <PlayerMatchPerformance>[]
              : <PlayerMatchPerformance>[performance],
        );
        engine.commitGameplayMatchResult(
          fixture: activeFixture,
          result: result,
        );
        engine.finalizeCareerMatchDay();
      } else {
        expect(() => engine.advanceSimulationDay(), returnsNormally);
      }
      expect(engine.validateSimulationIntegrity(), isTrue);
    }
  });

  test('match situation degrades safely with a one-player side', () {
    final owner = Match2DPlayer(
      id: 'owner', name: 'Owner', team: Match2DTeam.home, position: PlayerPosition.midfielder,
      overall: 70, pace: 70, shooting: 70, passing: 70, dribbling: 70, defending: 50, physical: 70,
      x: 50, y: 50, shirtNumber: 10, stamina: 90,
    );
    final state = Match2DState(
      players: [owner], benchPlayers: [], ballX: 50, ballY: 50, ballOwnerId: owner.id,
      ballTargetOwnerId: null, ballTravelProgress: 1, ballVelocityX: 0, ballVelocityY: 0,
      ballHeight: 0, ballSpin: 0, ballBounce: 0, targetHomeGoals: null, targetAwayGoals: null,
    );
    expect(() => MatchSituationEngine().build(state: state, owner: owner), returnsNormally);
  });
}
