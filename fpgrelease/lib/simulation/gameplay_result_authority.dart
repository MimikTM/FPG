/// Owns the emergent match-score ledger during the gameplay-authority phase.
/// It deliberately has no access to fixtures, standings, saves or career data.
class GameplayResultAuthority {
  int _homeGoals = 0;
  int _awayGoals = 0;

  void reset() {
    _homeGoals = 0;
    _awayGoals = 0;
  }

  void recordGoal({required bool home}) {
    if (home) {
      _homeGoals++;
    } else {
      _awayGoals++;
    }
  }

  GameplayResultSnapshot snapshot({
    required int homeGoals,
    required int awayGoals,
  }) {
    return GameplayResultSnapshot(
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      ledgerHomeGoals: _homeGoals,
      ledgerAwayGoals: _awayGoals,
    );
  }
}

class GameplayResultSnapshot {
  final int homeGoals;
  final int awayGoals;
  final int ledgerHomeGoals;
  final int ledgerAwayGoals;

  const GameplayResultSnapshot({
    required this.homeGoals,
    required this.awayGoals,
    required this.ledgerHomeGoals,
    required this.ledgerAwayGoals,
  });

  bool get consistent =>
      homeGoals == ledgerHomeGoals && awayGoals == ledgerAwayGoals;
}
