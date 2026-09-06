import '../models/match_2d.dart';
import '../models/match_result.dart';
import 'match_2d_engine.dart';

/// Phase 6 / 79: explicit boundary between gameplay and career persistence.
///
/// The adapter converts the authoritative interactive match state into the
/// existing MatchResult contract. It has no access to standings, fixtures or
/// saves, so it cannot create a second result authority.
class GameplayCareerIntegration {
  const GameplayCareerIntegration._();

  static MatchResult toMatchResult({
    required Match2DEngine engine,
    required String homeClubId,
    required String awayClubId,
    List<PlayerMatchPerformance> playerPerformances = const [],
  }) {
    final state = engine.state;
    if (state == null || !state.finished) {
      throw StateError('Nie można przekazać meczu do kariery przed końcem meczu.');
    }

    final snapshot = engine.gameplayResultSnapshot;
    if (engine.gameplayResultAuthority && !snapshot.consistent) {
      throw StateError('Gameplay score ledger jest niespójny z wynikiem meczu.');
    }

    final stats = state.stats;
    final events = engine.events.map(_toCareerEvent).toList(growable: false);

    return MatchResult(
      homeClubId: homeClubId,
      awayClubId: awayClubId,
      homeGoals: state.homeGoals,
      awayGoals: state.awayGoals,
      events: events,
      homeShots: stats.homeShots,
      awayShots: stats.awayShots,
      homeShotsOnTarget: stats.homeShotsOnTarget,
      awayShotsOnTarget: stats.awayShotsOnTarget,
      homeCorners: stats.homeCorners,
      awayCorners: stats.awayCorners,
      homeFouls: stats.homeFouls,
      awayFouls: stats.awayFouls,
      homeYellowCards: stats.homeYellowCards,
      awayYellowCards: stats.awayYellowCards,
      homeRedCards: stats.homeRedCards,
      awayRedCards: stats.awayRedCards,
      possessionHome: stats.homePossessionPercent.round(),
      playerPerformances: playerPerformances,
    );
  }

  static PlayerMatchEvent _toCareerEvent(Match2DEvent event) {
    return PlayerMatchEvent(
      playerId: event.playerId,
      minute: event.minute,
      type: event.type.name,
    );
  }
}
