enum MatchMomentumState { homeControl, awayControl, balanced, homeSurge, awaySurge }

class MatchMomentumSnapshot {
  final double home;
  final double away;
  final MatchMomentumState state;
  final int recentHomeShots;
  final int recentAwayShots;
  final int recentHomeChances;
  final int recentAwayChances;
  final int recentHomeGoals;
  final int recentAwayGoals;

  const MatchMomentumSnapshot({
    required this.home,
    required this.away,
    required this.state,
    required this.recentHomeShots,
    required this.recentAwayShots,
    required this.recentHomeChances,
    required this.recentAwayChances,
    required this.recentHomeGoals,
    required this.recentAwayGoals,
  });

  double get homeEdge => home - away;
  double get awayEdge => away - home;
}
