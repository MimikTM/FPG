import 'dart:math';
import '../models/match_2d.dart';
import 'gameplay_tuning.dart';

class ShotAssessment {
  final double xG;
  final double onTargetProbability;
  final double goalProbability;
  final double pressure;
  final double angleQuality;
  final String profile;

  const ShotAssessment({
    required this.xG,
    required this.onTargetProbability,
    required this.goalProbability,
    required this.pressure,
    required this.angleQuality,
    required this.profile,
  });
}

/// Contextual chance/shot model. It evaluates the quality of the opportunity;
/// it does not own the official match result or reconciliation transaction.
class ChanceCreationEngine {
  final Random random;
  ChanceCreationEngine({Random? random}) : random = random ?? Random();

  ShotAssessment assess({
    required Match2DState state,
    required Match2DPlayer shooter,
    double attackingStrength = 70,
    double defendingStrength = 70,
    String managerStyle = 'balanced',
  }) {
    final home = shooter.team == Match2DTeam.home;
    final goalX = home ? 100.0 : 0.0;
    final dx = goalX - shooter.x;
    final distance = sqrt(dx * dx + pow(shooter.y - 50, 2));
    final distanceFactor = (1 - (distance / 75)).clamp(0.05, 1.0);

    final defenders = state.players.where((p) => p.team != shooter.team && p.active && !p.redCard).toList();
    double nearest = 30;
    for (final d in defenders) {
      final dd = sqrt(pow(d.x - shooter.x, 2) + pow(d.y - shooter.y, 2));
      if (dd < nearest) nearest = dd;
    }
    final pressure = (1 - nearest / 18).clamp(0.0, 1.0);
    final angleQuality = (1 - (shooter.y - 50).abs() / 50).clamp(0.2, 1.0);
    final stamina = (shooter.stamina / 100).clamp(0.35, 1.0);

    final technique = shooter.shooting * .55 + shooter.overall * .25 + shooter.dribbling * .10 + shooter.physical * .10;
    final technique01 = (technique / 100).clamp(.1, .99);
    final quality = technique01 * .48 + distanceFactor * .27 + angleQuality * .15 + stamina * .10 - pressure * .28;
    final baseXg = quality.clamp(.015, .72);
    final tuning = GameplayTuning.combinedChanceModifier(
      attackingStrength: attackingStrength,
      defendingStrength: defendingStrength,
      managerStyle: managerStyle,
    );
    final xG = (baseXg * tuning).clamp(.015, .72);
    final onTarget = (xG * .95 + shooter.shooting / 100 * .30 - pressure * .12).clamp(.08, .92);
    final goal = (xG * (.62 + shooter.shooting / 200) * (1 - pressure * .22)).clamp(.01, .78);

    final profile = distance < 20
        ? 'close-range'
        : distance < 32
            ? 'inside-box'
            : distance < 48
                ? 'edge-of-box'
                : 'long-range';

    return ShotAssessment(
      xG: xG,
      onTargetProbability: onTarget,
      goalProbability: goal,
      pressure: pressure,
      angleQuality: angleQuality,
      profile: profile,
    );
  }

  bool resolveGoal(ShotAssessment shot, {double authorityModifier = 1.0}) {
    return random.nextDouble() < (shot.goalProbability * authorityModifier).clamp(0.0, .92);
  }
}
