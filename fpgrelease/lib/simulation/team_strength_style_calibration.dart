import 'dart:math';

import '../models/player.dart';
import 'full_match_simulation.dart';

/// Phase 6 / 72: verifies that team strength and tactical identity create
/// measurable differences in gameplay output. This is shadow-only telemetry.
class TeamStrengthStyleCalibration {
  final int matchesPerScenario;
  final int seed;
  final int maxTicks;

  const TeamStrengthStyleCalibration({
    this.matchesPerScenario = 3,
    this.seed = 72000,
    this.maxTicks = 12000,
  });

  TeamStrengthStyleCalibrationReport run({
    required List<Player> strong,
    required List<Player> weak,
    List<String> styles = const <String>[
      'possession', 'direct', 'counter', 'wing_play',
      'high_press', 'low_block', 'balanced',
    ],
  }) {
    final scenarios = <String, TeamStrengthScenario>{};
    var index = 0;
    for (final style in styles) {
      final strongResults = <FullMatchSimulationResult>[];
      final weakResults = <FullMatchSimulationResult>[];
      for (var i = 0; i < matchesPerScenario; i++) {
        final base = seed + index * 1009 + i;
        strongResults.add(FullMatchSimulation(random: Random(base), maxTicks: maxTicks).run(
          home: strong,
          away: weak,
          homeManagerStyle: style,
          awayManagerStyle: 'balanced',
          gameplayResultAuthority: true,
        ));
        weakResults.add(FullMatchSimulation(random: Random(base + 1), maxTicks: maxTicks).run(
          home: weak,
          away: strong,
          homeManagerStyle: style,
          awayManagerStyle: 'balanced',
          gameplayResultAuthority: true,
        ));
      }
      scenarios[style] = TeamStrengthScenario.fromResults(
        style: style,
        strong: strongResults,
        weak: weakResults,
      );
      index++;
    }

    return TeamStrengthStyleCalibrationReport(
      scenarios: scenarios,
      stylesTested: styles.length,
      matchesPerScenario: matchesPerScenario,
    );
  }
}

class TeamStrengthScenario {
  final String style;
  final double strongGoalsPerMatch;
  final double weakGoalsPerMatch;
  final double strongShotsPerMatch;
  final double weakShotsPerMatch;
  final double strongXgPerMatch;
  final double weakXgPerMatch;
  final double strongWinRate;
  final double weakWinRate;

  const TeamStrengthScenario({
    required this.style,
    required this.strongGoalsPerMatch,
    required this.weakGoalsPerMatch,
    required this.strongShotsPerMatch,
    required this.weakShotsPerMatch,
    required this.strongXgPerMatch,
    required this.weakXgPerMatch,
    required this.strongWinRate,
    required this.weakWinRate,
  });

  factory TeamStrengthScenario.fromResults({
    required String style,
    required List<FullMatchSimulationResult> strong,
    required List<FullMatchSimulationResult> weak,
  }) {
    double avg(List<FullMatchSimulationResult> rs, double Function(FullMatchSimulationResult) f) =>
        rs.isEmpty ? 0 : rs.map(f).reduce((a, b) => a + b) / rs.length;
    return TeamStrengthScenario(
      style: style,
      strongGoalsPerMatch: avg(strong, (r) => r.homeGoals.toDouble()),
      weakGoalsPerMatch: avg(weak, (r) => r.homeGoals.toDouble()),
      strongShotsPerMatch: avg(strong, (r) => r.homeShots.toDouble()),
      weakShotsPerMatch: avg(weak, (r) => r.homeShots.toDouble()),
      strongXgPerMatch: avg(strong, (r) => r.expectedGoalsHome.toDouble()),
      weakXgPerMatch: avg(weak, (r) => r.expectedGoalsHome.toDouble()),
      strongWinRate: strong.isEmpty ? 0 : strong.where((r) => r.homeGoals > r.awayGoals).length / strong.length,
      weakWinRate: weak.isEmpty ? 0 : weak.where((r) => r.homeGoals > r.awayGoals).length / weak.length,
    );
  }

  bool get strengthSignal =>
      strongXgPerMatch > weakXgPerMatch ||
      strongShotsPerMatch > weakShotsPerMatch ||
      strongGoalsPerMatch > weakGoalsPerMatch;
}

class TeamStrengthStyleCalibrationReport {
  final Map<String, TeamStrengthScenario> scenarios;
  final int stylesTested;
  final int matchesPerScenario;

  const TeamStrengthStyleCalibrationReport({
    required this.scenarios,
    required this.stylesTested,
    required this.matchesPerScenario,
  });

  bool get allHaveStrengthSignal =>
      scenarios.isNotEmpty && scenarios.values.every((s) => s.strengthSignal);

  bool get styleDiversitySignal {
    if (scenarios.length < 2) return false;
    final xg = scenarios.values.map((s) => s.strongXgPerMatch).toList();
    final spread = xg.reduce(max) - xg.reduce(min);
    return spread >= 0.05;
  }

  bool get passed => allHaveStrengthSignal && styleDiversitySignal;
}
