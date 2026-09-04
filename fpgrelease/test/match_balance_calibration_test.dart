import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/simulation/match_balance_calibration.dart';
import 'package:fpg/simulation/shadow_match_benchmark.dart';

void main() {
  test('calibration passes a healthy statistical profile', () {
    const report = ShadowBenchmarkReport(
      matches: 100,
      completedMatches: 100,
      inconsistentLedgers: 0,
      totalGoals: 240,
      scorelessMatches: 12,
      homeWins: 44,
      draws: 24,
      awayWins: 32,
      totalShots: 1200,
      totalSaves: 360,
      totalFouls: 1200,
      totalCards: 320,
      totalCorners: 700,
      totalSubstitutions: 500,
      averageGoals: 2.4,
      averageShots: 12,
      averageFouls: 12,
      averageCards: 3.2,
      averageCorners: 7,
      averageSubstitutions: 5,
      styleCount: 7,
      matchesPerPair: 2,
    );
    final result = const MatchBalanceCalibration().evaluate(report);
    expect(result.passed, isTrue);
    expect(result.checks.values.every((v) => v), isTrue);
  });

  test('calibration recommends correction for extreme goal volume', () {
    const report = ShadowBenchmarkReport(
      matches: 10,
      completedMatches: 10,
      inconsistentLedgers: 0,
      totalGoals: 60,
      scorelessMatches: 0,
      homeWins: 5,
      draws: 0,
      awayWins: 5,
      totalShots: 120,
      totalSaves: 30,
      totalFouls: 120,
      totalCards: 20,
      totalCorners: 70,
      totalSubstitutions: 50,
      averageGoals: 6,
      averageShots: 12,
      averageFouls: 12,
      averageCards: 2,
      averageCorners: 7,
      averageSubstitutions: 5,
      styleCount: 7,
      matchesPerPair: 2,
    );
    final result = const MatchBalanceCalibration().evaluate(report);
    expect(result.passed, isFalse);
    expect(result.recommendations.join(' '), contains('skuteczność'));
  });
}
