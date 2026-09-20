import 'dart:math';
import '../models/match_2d.dart';

/// Resolves first touch and physical contact without deciding the official
/// match result. It turns a pass reception into a small football interaction:
/// clean control, heavy touch, contested ball or turnover.
class MatchContactEngine {
  final Random random;
  MatchContactEngine({Random? random}) : random = random ?? Random();

  FirstTouchResult firstTouch({
    required Match2DPlayer receiver,
    required double ballSpeed,
    required double pressure,
    required double ballHeight,
    bool controlled = false,
  }) {
    final technical = receiver.overall * .42 + receiver.passing * .18 + receiver.dribbling * .24;
    final physical = receiver.physical * .08 + receiver.pace * .08;
    final fatigue = (100 - receiver.stamina) * .16;
    final heightPenalty = ballHeight > 3 ? (ballHeight - 3) * 1.8 : 0;
    final pressurePenalty = pressure.clamp(0, 20) * .72;
    final speedPenalty = ballSpeed.clamp(0, 30) * .48;
    final controlBonus = controlled ? 5.0 : 0.0;
    final score = technical + physical + controlBonus - fatigue - heightPenalty - pressurePenalty - speedPenalty + random.nextDouble() * 6 - 3;

    if (score >= 62) return const FirstTouchResult(FirstTouchOutcome.clean, 0.85);
    if (score >= 48) return const FirstTouchResult(FirstTouchOutcome.good, 0.60);
    if (score >= 34) return const FirstTouchResult(FirstTouchOutcome.heavy, 0.35);
    return const FirstTouchResult(FirstTouchOutcome.miscontrol, 0.08);
  }

  PhysicalDuelResult shoulderToShoulder({
    required Match2DPlayer first,
    required Match2DPlayer second,
    required double speed,
    required double space,
  }) {
    final firstScore = _physical(first) + first.pace * .18 + space * .25 - (100 - first.stamina) * .14;
    final secondScore = _physical(second) + second.pace * .18 + space * .25 - (100 - second.stamina) * .14;
    final delta = firstScore - secondScore + random.nextDouble() * 6 - 3;
    final contactRisk = (speed * .025 + (18 - space).clamp(0, 18) * .018).clamp(.05, .65);
    if (delta.abs() < 5) return PhysicalDuelResult(PhysicalDuelOutcome.contested, delta, contactRisk);
    return PhysicalDuelResult(delta > 0 ? PhysicalDuelOutcome.firstWins : PhysicalDuelOutcome.secondWins, delta, contactRisk);
  }

  double _physical(Match2DPlayer p) => p.physical * .58 + p.overall * .24 + p.defending * .10 + p.dribbling * .08;
}

enum FirstTouchOutcome { clean, good, heavy, miscontrol }

class FirstTouchResult {
  final FirstTouchOutcome outcome;
  final double retention;
  const FirstTouchResult(this.outcome, this.retention);
}

enum PhysicalDuelOutcome { firstWins, secondWins, contested }

class PhysicalDuelResult {
  final PhysicalDuelOutcome outcome;
  final double margin;
  final double foulRisk;
  const PhysicalDuelResult(this.outcome, this.margin, this.foulRisk);
}
