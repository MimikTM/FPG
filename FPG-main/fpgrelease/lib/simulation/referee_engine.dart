import 'dart:math';
import '../models/match_2d.dart';

/// Resolves the disciplinary/restart consequence of a physical challenge.
/// This is runtime match logic only; it never owns the official score.
class RefereeEngine {
  final Random random;
  RefereeEngine({Random? random}) : random = random ?? Random();

  RefereeDecision resolveChallenge({
    required Match2DPlayer defender,
    required Match2DPlayer attacker,
    required double distance,
    required double speed,
    required bool inPenaltyArea,
    required int minute,
  }) {
    final proximity = ((12 - distance).clamp(0, 12)) / 12;
    final speedFactor = (speed / 12).clamp(0, 1);
    final timing = (defender.defending * .55 + defender.overall * .20 + defender.stamina * .10) / 100;
    final control = (attacker.dribbling * .35 + attacker.pace * .15) / 100;
    final aggression = defender.physical / 100;
    final baseRisk = .035 + proximity * .18 + speedFactor * .10 + aggression * .05 + control * .03 - timing * .08;
    final cardRisk = (baseRisk * 1.7 + (defender.yellowCard ? .10 : 0) + (minute >= 75 ? .025 : 0)).clamp(.01, .55);
    final foul = random.nextDouble() < baseRisk.clamp(.01, .42);
    if (!foul) return const RefereeDecision(outcome: RefereeOutcome.clean, restart: RefereeRestart.playOn);

    // Dangerous/late contact can become a straight red, but remains rare.
    final dangerous = speedFactor > .72 && proximity > .55 && defender.defending < 55;
    final straightRed = dangerous && random.nextDouble() < .035;
    final secondYellow = defender.yellowCard && random.nextDouble() < (.035 + proximity * .035);
    final yellow = !straightRed && !secondYellow && random.nextDouble() < cardRisk;

    // Advantage is more likely when the attacking team keeps a meaningful attack.
    final advantage = !inPenaltyArea && attacker.pace >= 72 && random.nextDouble() < .16;
    if (straightRed || secondYellow) {
      return RefereeDecision(
        outcome: RefereeOutcome.foul,
        restart: advantage ? RefereeRestart.advantage : (inPenaltyArea ? RefereeRestart.penalty : RefereeRestart.freeKick),
        card: straightRed || secondYellow ? RefereeCard.red : RefereeCard.none,
        advantage: advantage,
      );
    }
    if (yellow) {
      return RefereeDecision(
        outcome: RefereeOutcome.foul,
        restart: advantage ? RefereeRestart.advantage : (inPenaltyArea ? RefereeRestart.penalty : RefereeRestart.freeKick),
        card: RefereeCard.yellow,
        advantage: advantage,
      );
    }
    return RefereeDecision(
      outcome: RefereeOutcome.foul,
      restart: advantage ? RefereeRestart.advantage : (inPenaltyArea ? RefereeRestart.penalty : RefereeRestart.freeKick),
      card: RefereeCard.none,
      advantage: advantage,
    );
  }
}

enum RefereeOutcome { clean, foul }
enum RefereeRestart { playOn, advantage, freeKick, penalty }
enum RefereeCard { none, yellow, red }

class RefereeDecision {
  final RefereeOutcome outcome;
  final RefereeRestart restart;
  final RefereeCard card;
  final bool advantage;
  const RefereeDecision({required this.outcome, required this.restart, this.card = RefereeCard.none, this.advantage = false});

  bool get isFoul => outcome == RefereeOutcome.foul;
}
