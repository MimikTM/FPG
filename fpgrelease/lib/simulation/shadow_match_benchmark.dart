import 'dart:math';

import '../models/player.dart';
import 'full_match_simulation.dart';

/// Phase 6 / 70: non-invasive balance benchmark.
///
/// Runs gameplay-authority matches without touching league fixtures, saves or
/// reconciliation. It is intentionally a diagnostics layer around
/// FullMatchSimulation rather than another result authority.
class ShadowMatchBenchmark {
  final int matchesPerPair;
  final int seed;
  final int maxTicks;
  final List<String> styles;

  const ShadowMatchBenchmark({
    this.matchesPerPair = 8,
    this.seed = 70000,
    this.maxTicks = 12000,
    this.styles = const <String>[
      'possession',
      'direct',
      'counter',
      'wing_play',
      'high_press',
      'low_block',
      'balanced',
    ],
  });

  ShadowBenchmarkReport run({
    required List<Player> home,
    required List<Player> away,
  }) {
    final results = <FullMatchSimulationResult>[];
    var pairIndex = 0;
    for (final homeStyle in styles) {
      for (final awayStyle in styles) {
        for (var i = 0; i < matchesPerPair; i++) {
          final random = Random(seed + pairIndex * 997 + i);
          results.add(FullMatchSimulation(random: random, maxTicks: maxTicks).run(
            home: home,
            away: away,
            homeManagerStyle: homeStyle,
            awayManagerStyle: awayStyle,
            gameplayResultAuthority: true,
          ));
        }
        pairIndex++;
      }
    }
    return ShadowBenchmarkReport.fromResults(
      results: results,
      styleCount: styles.length,
      matchesPerPair: matchesPerPair,
    );
  }
}

class ShadowBenchmarkReport {
  final int matches;
  final int completedMatches;
  final int inconsistentLedgers;
  final int totalGoals;
  final int scorelessMatches;
  final int homeWins;
  final int draws;
  final int awayWins;
  final int totalShots;
  final int totalSaves;
  final int totalFouls;
  final int totalCards;
  final int totalCorners;
  final int totalSubstitutions;
  final double averageGoals;
  final double averageShots;
  final double averageFouls;
  final double averageCards;
  final double averageCorners;
  final double averageSubstitutions;
  final int styleCount;
  final int matchesPerPair;

  const ShadowBenchmarkReport({
    required this.matches,
    required this.completedMatches,
    required this.inconsistentLedgers,
    required this.totalGoals,
    required this.scorelessMatches,
    required this.homeWins,
    required this.draws,
    required this.awayWins,
    required this.totalShots,
    required this.totalSaves,
    required this.totalFouls,
    required this.totalCards,
    required this.totalCorners,
    required this.totalSubstitutions,
    required this.averageGoals,
    required this.averageShots,
    required this.averageFouls,
    required this.averageCards,
    required this.averageCorners,
    required this.averageSubstitutions,
    required this.styleCount,
    required this.matchesPerPair,
  });

  factory ShadowBenchmarkReport.fromResults({
    required List<FullMatchSimulationResult> results,
    required int styleCount,
    required int matchesPerPair,
  }) {
    final matches = results.length;
    final completed = results.where((r) => r.completed).length;
    final inconsistent = results.where((r) => !r.scoreLedgerConsistent).length;
    final goals = results.fold<int>(0, (sum, r) => sum + r.totalGoals);
    final shots = results.fold<int>(0, (sum, r) => sum + r.shots);
    final saves = results.fold<int>(0, (sum, r) => sum + r.saves);
    final fouls = results.fold<int>(0, (sum, r) => sum + r.fouls);
    final cards = results.fold<int>(0, (sum, r) => sum + r.cards);
    final corners = results.fold<int>(0, (sum, r) => sum + r.corners);
    final subs = results.fold<int>(0, (sum, r) => sum + r.substitutions);
    return ShadowBenchmarkReport(
      matches: matches,
      completedMatches: completed,
      inconsistentLedgers: inconsistent,
      totalGoals: goals,
      scorelessMatches: results.where((r) => r.totalGoals == 0).length,
      homeWins: results.where((r) => r.homeGoals > r.awayGoals).length,
      draws: results.where((r) => r.homeGoals == r.awayGoals).length,
      awayWins: results.where((r) => r.awayGoals > r.homeGoals).length,
      totalShots: shots,
      totalSaves: saves,
      totalFouls: fouls,
      totalCards: cards,
      totalCorners: corners,
      totalSubstitutions: subs,
      averageGoals: matches == 0 ? 0 : goals / matches,
      averageShots: matches == 0 ? 0 : shots / matches,
      averageFouls: matches == 0 ? 0 : fouls / matches,
      averageCards: matches == 0 ? 0 : cards / matches,
      averageCorners: matches == 0 ? 0 : corners / matches,
      averageSubstitutions: matches == 0 ? 0 : subs / matches,
      styleCount: styleCount,
      matchesPerPair: matchesPerPair,
    );
  }

  double get completionRate => matches == 0 ? 0 : completedMatches / matches;
  double get ledgerConsistencyRate => matches == 0 ? 1 : 1 - inconsistentLedgers / matches;
  double get scorelessRate => matches == 0 ? 0 : scorelessMatches / matches;
  double get homeWinRate => matches == 0 ? 0 : homeWins / matches;
  double get drawRate => matches == 0 ? 0 : draws / matches;
  double get awayWinRate => matches == 0 ? 0 : awayWins / matches;

  /// Operational gate: catches broken authority or incomplete simulation, but
  /// deliberately does not declare a football-balance pass/fail threshold.
  bool get infrastructureGatePassed =>
      matches > 0 && completedMatches == matches && inconsistentLedgers == 0;
}
