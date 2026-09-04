import 'shadow_match_benchmark.dart';

/// Phase 6 / 71: gameplay balance calibration gate.
///
/// This layer does not mutate fixtures, saves or gameplay authority. It turns
/// shadow-match telemetry into stable diagnostic bands so tuning can happen
/// from measured output instead of intuition.
class MatchBalanceCalibration {
  const MatchBalanceCalibration();

  MatchBalanceCalibrationReport evaluate(ShadowBenchmarkReport report) {
    final checks = <String, bool>{
      'infrastructure': report.infrastructureGatePassed,
      'goals': _between(report.averageGoals, 1.6, 3.8),
      'shots': _between(report.averageShots, 6.0, 22.0),
      'fouls': _between(report.averageFouls, 4.0, 24.0),
      'cards': _between(report.averageCards, 0.2, 7.0),
      'corners': _between(report.averageCorners, 2.0, 14.0),
      'scoreless': _between(report.scorelessRate, 0.03, 0.30),
    };
    return MatchBalanceCalibrationReport(
      passed: checks.values.every((value) => value),
      checks: checks,
      recommendations: _recommend(report, checks),
    );
  }

  bool _between(double value, double min, double max) =>
      value >= min && value <= max;

  List<String> _recommend(ShadowBenchmarkReport r, Map<String, bool> checks) {
    final out = <String>[];
    if (!checks['goals']!) {
      out.add(r.averageGoals < 1.6
          ? 'Zwiększyć jakość/objętość sytuacji bramkowych.'
          : 'Obniżyć skuteczność strzałów lub ograniczyć wysokiej jakości okazje.');
    }
    if (!checks['shots']!) {
      out.add(r.averageShots < 6
          ? 'Zwiększyć częstotliwość wejść w fazę strzału.'
          : 'Ograniczyć nadmiarowych prób strzeleckich.');
    }
    if (!checks['fouls']!) {
      out.add(r.averageFouls < 4
          ? 'Lekko zwiększyć kontakt/tackle frequency.'
          : 'Zmniejszyć częstotliwość fauli i ryzyko wejść.');
    }
    if (!checks['cards']!) {
      out.add(r.averageCards < .2
          ? 'Zwiększyć ekspozycję na kartkowane przewinienia.'
          : 'Zaostrzyć próg dla kartek, zachowując czerwone jako rzadkie.');
    }
    if (!checks['corners']!) {
      out.add(r.averageCorners < 2
          ? 'Zwiększyć udział akcji kończących się odbiciem/rożnym.'
          : 'Ograniczyć zbyt częste wyjścia piłki na róg.');
    }
    if (!checks['scoreless']!) {
      out.add(r.scorelessRate < .03
          ? 'Model produkuje zbyt mało 0:0.'
          : 'Model produkuje zbyt dużo 0:0.');
    }
    if (out.isEmpty) out.add('Statystyczny profil mieści się w aktualnych pasmach kalibracyjnych.');
    return out;
  }
}

class MatchBalanceCalibrationReport {
  final bool passed;
  final Map<String, bool> checks;
  final List<String> recommendations;

  const MatchBalanceCalibrationReport({
    required this.passed,
    required this.checks,
    required this.recommendations,
  });
}
