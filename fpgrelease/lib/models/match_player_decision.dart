import 'player.dart';
import 'match_2d.dart';

/// Contextual, runtime-only decision for the player currently on the ball.
/// It never owns the official match result; it only chooses the football action.
enum MatchPlayerDecisionAction { pass, carry, dribble, cross, shoot, recycle, clear }

class MatchPlayerDecisionContext {
  final Match2DPlayer player;
  final Match2DPlayer? nearestOpponent;
  final Match2DPlayer? bestTeammate;
  final double pressure;
  final double forwardSpace;
  final double distanceToGoal;
  final double scoreUrgency;
  final double transitionUrgency;
  final bool inFinalThird;
  final bool losing;
  final bool leading;
  final bool underHeavyPressure;

  const MatchPlayerDecisionContext({
    required this.player,
    required this.nearestOpponent,
    required this.bestTeammate,
    required this.pressure,
    required this.forwardSpace,
    required this.distanceToGoal,
    required this.scoreUrgency,
    required this.transitionUrgency,
    required this.inFinalThird,
    required this.losing,
    required this.leading,
    required this.underHeavyPressure,
  });
}

class MatchPlayerDecision {
  final MatchPlayerDecisionAction action;
  final double confidence;
  final String reason;

  const MatchPlayerDecision({
    required this.action,
    required this.confidence,
    required this.reason,
  });
}

/// Small utility used by Match2DEngine. Scores are intentionally interpretable
/// rather than opaque ML weights so gameplay remains deterministic/debuggable.
class MatchPlayerDecisionEngine {
  const MatchPlayerDecisionEngine();

  MatchPlayerDecision choose(MatchPlayerDecisionContext c) {
    final p = c.player;
    final scores = <MatchPlayerDecisionAction, double>{
      MatchPlayerDecisionAction.pass: 0.25 + p.passing * .006,
      MatchPlayerDecisionAction.carry: 0.10 + p.pace * .004 + p.dribbling * .003,
      MatchPlayerDecisionAction.dribble: 0.08 + p.dribbling * .005,
      MatchPlayerDecisionAction.cross: 0.03 + p.passing * .003,
      MatchPlayerDecisionAction.shoot: 0.01 + p.shooting * .002,
      MatchPlayerDecisionAction.recycle: 0.12 + p.passing * .003,
      MatchPlayerDecisionAction.clear: 0.02 + p.defending * .003,
    };

    if (c.distanceToGoal < 22 && p.position != PlayerPosition.goalkeeper) {
      scores[MatchPlayerDecisionAction.shoot] = scores[MatchPlayerDecisionAction.shoot]! +
          .55 + p.shooting / 250;
    }
    if (c.inFinalThird && p.position == PlayerPosition.winger) {
      scores[MatchPlayerDecisionAction.cross] = scores[MatchPlayerDecisionAction.cross]! + .42;
      scores[MatchPlayerDecisionAction.dribble] = scores[MatchPlayerDecisionAction.dribble]! + .16;
    }
    if (c.forwardSpace > 14 && c.pressure > 8) {
      scores[MatchPlayerDecisionAction.carry] = scores[MatchPlayerDecisionAction.carry]! + .42;
    }
    if (c.underHeavyPressure) {
      scores[MatchPlayerDecisionAction.pass] = scores[MatchPlayerDecisionAction.pass]! + .22;
      scores[MatchPlayerDecisionAction.recycle] = scores[MatchPlayerDecisionAction.recycle]! + .26;
      scores[MatchPlayerDecisionAction.dribble] = scores[MatchPlayerDecisionAction.dribble]! - .18;
    }
    if (c.losing) {
      scores[MatchPlayerDecisionAction.carry] = scores[MatchPlayerDecisionAction.carry]! + .10 * c.scoreUrgency;
      scores[MatchPlayerDecisionAction.dribble] = scores[MatchPlayerDecisionAction.dribble]! + .12 * c.scoreUrgency;
      scores[MatchPlayerDecisionAction.shoot] = scores[MatchPlayerDecisionAction.shoot]! + .12 * c.scoreUrgency;
    }
    if (c.leading) {
      scores[MatchPlayerDecisionAction.recycle] = scores[MatchPlayerDecisionAction.recycle]! + .22 * c.scoreUrgency;
      scores[MatchPlayerDecisionAction.pass] = scores[MatchPlayerDecisionAction.pass]! + .10;
      scores[MatchPlayerDecisionAction.shoot] = scores[MatchPlayerDecisionAction.shoot]! - .08;
    }
    if (p.position == PlayerPosition.defender && c.distanceToGoal > 55) {
      scores[MatchPlayerDecisionAction.pass] = scores[MatchPlayerDecisionAction.pass]! + .12;
      scores[MatchPlayerDecisionAction.clear] = scores[MatchPlayerDecisionAction.clear]! + (c.underHeavyPressure ? .35 : 0);
    }
    if (p.position == PlayerPosition.striker) {
      scores[MatchPlayerDecisionAction.shoot] = scores[MatchPlayerDecisionAction.shoot]! + .10;
    }

    var best = MatchPlayerDecisionAction.pass;
    var bestScore = double.negativeInfinity;
    scores.forEach((action, score) {
      if (score > bestScore) {
        best = action;
        bestScore = score;
      }
    });
    return MatchPlayerDecision(
      action: best,
      confidence: bestScore.clamp(0.0, 1.0),
      reason: _reason(best, c),
    );
  }

  String _reason(MatchPlayerDecisionAction action, MatchPlayerDecisionContext c) {
    switch (action) {
      case MatchPlayerDecisionAction.shoot: return 'przestrzeń do strzału';
      case MatchPlayerDecisionAction.cross: return 'skrzydło + strefa dośrodkowania';
      case MatchPlayerDecisionAction.dribble: return 'przewaga 1v1 / potrzeba progresji';
      case MatchPlayerDecisionAction.carry: return 'wolna przestrzeń przed zawodnikiem';
      case MatchPlayerDecisionAction.recycle: return 'presja lub ochrona wyniku';
      case MatchPlayerDecisionAction.clear: return 'bezpieczne oddalenie zagrożenia';
      case MatchPlayerDecisionAction.pass: return c.bestTeammate == null ? 'bezpieczne podanie' : 'najlepsza dostępna opcja zespołowa';
    }
  }
}
