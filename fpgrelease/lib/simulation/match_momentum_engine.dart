import '../models/match_2d.dart';
import '../models/match_momentum.dart';

class MatchMomentumEngine {
  const MatchMomentumEngine();

  MatchMomentumSnapshot evaluate({
    required Match2DState state,
    required List<Match2DEvent> events,
    String? possessionTeam,
  }) {
    final windowStart = state.minute - 12;
    final recent = events.where((e) => e.minute >= windowStart).toList();
    int homeShots = 0, awayShots = 0, homeChances = 0, awayChances = 0;
    int homeGoals = 0, awayGoals = 0;
    for (final e in recent) {
      final player = state.players.where((p) => p.id == e.playerId).firstOrNull;
      final isHome = player?.team == Match2DTeam.home;
      if (e.type == Match2DEventType.shot || e.type == Match2DEventType.save) {
        if (isHome) homeShots++; else awayShots++;
      }
      if (e.isChance || e.isKeyMoment) {
        if (isHome) homeChances++; else awayChances++;
      }
      if (e.type == Match2DEventType.goal) {
        if (isHome) homeGoals++; else awayGoals++;
      }
    }

    final possessionBias = state.stats.homePossessionSeconds - state.stats.awayPossessionSeconds;
    final homePoss = possessionBias.clamp(-720, 720) / 720.0;
    final edge = ((homeShots - awayShots) * 7.0 +
            (homeChances - awayChances) * 5.0 +
            (homeGoals - awayGoals) * 24.0 +
            homePoss * 9.0 +
            (possessionTeam == 'home' ? 4.0 : possessionTeam == 'away' ? -4.0 : 0.0))
        .clamp(-60.0, 60.0);
    final home = (50.0 + edge).clamp(0.0, 100.0);
    final away = (50.0 - edge).clamp(0.0, 100.0);
    final stateValue = edge >= 25
        ? MatchMomentumState.homeSurge
        : edge <= -25
            ? MatchMomentumState.awaySurge
            : edge >= 10
                ? MatchMomentumState.homeControl
                : edge <= -10
                    ? MatchMomentumState.awayControl
                    : MatchMomentumState.balanced;
    return MatchMomentumSnapshot(
      home: home,
      away: away,
      state: stateValue,
      recentHomeShots: homeShots,
      recentAwayShots: awayShots,
      recentHomeChances: homeChances,
      recentAwayChances: awayChances,
      recentHomeGoals: homeGoals,
      recentAwayGoals: awayGoals,
    );
  }
}
