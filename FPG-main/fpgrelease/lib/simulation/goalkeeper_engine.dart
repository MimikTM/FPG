import '../models/player.dart';
import 'dart:math';
import '../models/match_2d.dart';

class GoalkeeperAssessment {
  final double positioning;
  final double saveProbability;
  final double oneOnOneRisk;
  final double distanceToLine;
  final bool shouldSweep;

  const GoalkeeperAssessment({
    required this.positioning,
    required this.saveProbability,
    required this.oneOnOneRisk,
    required this.distanceToLine,
    required this.shouldSweep,
  });
}

/// Gameplay-only goalkeeper model. It evaluates positioning and reaction
/// quality without owning the official result or save transaction.
class GoalkeeperEngine {
  const GoalkeeperEngine();

  Match2DPlayer? goalkeeper(Match2DState state, Match2DTeam team) {
    for (final p in state.players) {
      if (p.active && !p.redCard && p.team == team && p.position == PlayerPosition.goalkeeper) {
        return p;
      }
    }
    return null;
  }

  GoalkeeperAssessment assess({
    required Match2DState state,
    required Match2DPlayer goalkeeper,
    required Match2DPlayer shooter,
  }) {
    final home = goalkeeper.team == Match2DTeam.home;
    final lineX = home ? 4.0 : 96.0;
    final distanceToLine = (goalkeeper.x - lineX).abs();
    final ballGoalDistance = home ? (100 - shooter.x) : shooter.x;
    final lateralError = (goalkeeper.y - shooter.y).abs();
    final angleCoverage = (1 - lateralError / 45).clamp(0.0, 1.0);
    final lineDiscipline = (1 - distanceToLine / 13).clamp(0.0, 1.0);
    final positioning = (lineDiscipline * .45 + angleCoverage * .55).clamp(0.0, 1.0);
    final keeperSkill = (goalkeeper.overall * .42 + goalkeeper.defending * .30 +
            goalkeeper.physical * .12 + goalkeeper.pace * .16) / 100;
    final reaction = keeperSkill.clamp(.25, .98);
    final oneOnOneRisk = ballGoalDistance < 16
        ? (1 - positioning) * .55 + (1 - reaction) * .35
        : 0.0;
    final shotDistance = sqrt(pow(shooter.x - lineX, 2) + pow(shooter.y - 50, 2));
    final shouldSweep = ballGoalDistance < 22 && shotDistance > 8 && positioning < .72;
    final saveProbability = (0.12 + positioning * .24 + reaction * .34 -
            oneOnOneRisk * .20).clamp(.08, .72);
    return GoalkeeperAssessment(
      positioning: positioning,
      saveProbability: saveProbability,
      oneOnOneRisk: oneOnOneRisk,
      distanceToLine: distanceToLine,
      shouldSweep: shouldSweep,
    );
  }

  void positionKeeper({required Match2DState state, required Match2DPlayer goalkeeper}) {
    final home = goalkeeper.team == Match2DTeam.home;
    final lineX = home ? 4.0 : 96.0;
    final depth = home ? (state.ballX / 100).clamp(0.0, 1.0) : ((100 - state.ballX) / 100).clamp(0.0, 1.0);
    final advance = (depth * 8.0).clamp(0.0, 7.0);
    goalkeeper.x = home ? lineX + advance : lineX - advance;
    goalkeeper.y = (50 + (state.ballY - 50) * .32).clamp(5.0, 95.0).toDouble();
  }
}
