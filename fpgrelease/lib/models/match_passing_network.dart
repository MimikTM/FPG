enum PassingZone { defensive, middle, attacking, wideLeft, wideRight }

class TeamPassingNetworkSnapshot {
  final int possessions;
  final int completedPasses;
  final int progressivePasses;
  final int finalThirdEntries;
  final int turnovers;
  final int longestSequence;
  final double averageSequenceLength;
  final double averagePassDistance;
  final double widthUsage;

  const TeamPassingNetworkSnapshot({
    required this.possessions,
    required this.completedPasses,
    required this.progressivePasses,
    required this.finalThirdEntries,
    required this.turnovers,
    required this.longestSequence,
    required this.averageSequenceLength,
    required this.averagePassDistance,
    required this.widthUsage,
  });

  double get passCompletionRate => completedPasses == 0 ? 0 : 1.0;
  double get progressionRate => completedPasses == 0 ? 0 : progressivePasses / completedPasses;
}

class PassingNetworkTracker {
  int _homePossessions = 0, _awayPossessions = 0;
  int _homeCompleted = 0, _awayCompleted = 0;
  int _homeProgressive = 0, _awayProgressive = 0;
  int _homeFinalThird = 0, _awayFinalThird = 0;
  int _homeTurnovers = 0, _awayTurnovers = 0;
  int _homeSequence = 0, _awaySequence = 0;
  int _homeLongest = 0, _awayLongest = 0;
  double _homeDistance = 0, _awayDistance = 0;
  int _homePassDistanceSamples = 0, _awayPassDistanceSamples = 0;
  int _homeWide = 0, _awayWide = 0;
  final List<int> _homeSequences = <int>[];
  final List<int> _awaySequences = <int>[];

  void reset() {
    _homePossessions = _awayPossessions = 0;
    _homeCompleted = _awayCompleted = 0;
    _homeProgressive = _awayProgressive = 0;
    _homeFinalThird = _awayFinalThird = 0;
    _homeTurnovers = _awayTurnovers = 0;
    _homeSequence = _awaySequence = 0;
    _homeLongest = _awayLongest = 0;
    _homeDistance = _awayDistance = 0;
    _homePassDistanceSamples = _awayPassDistanceSamples = 0;
    _homeWide = _awayWide = 0;
    _homeSequences.clear();
    _awaySequences.clear();
  }

  void possessionStarted(bool home) {
    if (home) { _homePossessions++; _homeSequence = 1; }
    else { _awayPossessions++; _awaySequence = 1; }
  }

  void pass({required bool home, required double distance, required double forwardProgress, required double targetY}) {
    if (home) {
      _homeCompleted++; _homeSequence++;
      _homeLongest = _homeLongest > _homeSequence ? _homeLongest : _homeSequence;
      _homeDistance += distance; _homePassDistanceSamples++;
      if (forwardProgress >= 7) _homeProgressive++;
      if (targetY < 22 || targetY > 78) _homeWide++;
    } else {
      _awayCompleted++; _awaySequence++;
      _awayLongest = _awayLongest > _awaySequence ? _awayLongest : _awaySequence;
      _awayDistance += distance; _awayPassDistanceSamples++;
      if (forwardProgress >= 7) _awayProgressive++;
      if (targetY < 22 || targetY > 78) _awayWide++;
    }
  }

  void finalThirdEntry(bool home) { if (home) _homeFinalThird++; else _awayFinalThird++; }

  void turnover(bool home) {
    if (home) { _homeTurnovers++; if (_homeSequence > 0) _homeSequences.add(_homeSequence); _homeSequence = 0; }
    else { _awayTurnovers++; if (_awaySequence > 0) _awaySequences.add(_awaySequence); _awaySequence = 0; }
  }

  TeamPassingNetworkSnapshot homeSnapshot() => _snapshot(true);
  TeamPassingNetworkSnapshot awaySnapshot() => _snapshot(false);

  TeamPassingNetworkSnapshot _snapshot(bool home) {
    final seqs = home ? _homeSequences : _awaySequences;
    final active = home ? _homeSequence : _awaySequence;
    final totalSeq = seqs.fold<int>(0, (a, b) => a + b) + active;
    final count = seqs.length + (active > 0 ? 1 : 0);
    final completed = home ? _homeCompleted : _awayCompleted;
    return TeamPassingNetworkSnapshot(
      possessions: home ? _homePossessions : _awayPossessions,
      completedPasses: completed,
      progressivePasses: home ? _homeProgressive : _awayProgressive,
      finalThirdEntries: home ? _homeFinalThird : _awayFinalThird,
      turnovers: home ? _homeTurnovers : _awayTurnovers,
      longestSequence: home ? _homeLongest : _awayLongest,
      averageSequenceLength: count == 0 ? 0 : totalSeq / count,
      averagePassDistance: (home ? _homePassDistanceSamples : _awayPassDistanceSamples) == 0 ? 0 : (home ? _homeDistance : _awayDistance) / (home ? _homePassDistanceSamples : _awayPassDistanceSamples),
      widthUsage: completed == 0 ? 0 : (home ? _homeWide : _awayWide) / completed,
    );
  }
}
