import 'dart:math';
import 'match_2d.dart';

/// Shared team transition state used by the live match AI.
/// It is derived runtime state; the club's managerStyle remains authoritative.
enum MatchTransitionPhase {
  inPossession,
  loss,
  counterPress,
  retreat,
  settledDefence,
  recovery,
}

class MatchTransitionProfile {
  final MatchTransitionPhase phase;
  final double lineHeight;
  final double compactness;
  final double cover;
  final double runnerTracking;
  final double counterPress;
  final double retreatSpeed;

  const MatchTransitionProfile({
    required this.phase,
    required this.lineHeight,
    required this.compactness,
    required this.cover,
    required this.runnerTracking,
    required this.counterPress,
    required this.retreatSpeed,
  });

  static MatchTransitionPhase phaseFor({
    required Match2DState state,
    required Match2DTeam team,
    required Match2DPlayer? owner,
    required Match2DPlayer? previousOwner,
  }) {
    if (owner != null && owner.team == team) return MatchTransitionPhase.inPossession;
    if (previousOwner != null && previousOwner.team == team && owner != null && owner.team != team) {
      return MatchTransitionPhase.loss;
    }
    if (owner != null && owner.team != team) {
      final distance = _nearestDistance(state, team, owner);
      if (distance < 16) return MatchTransitionPhase.counterPress;
      if (distance > 30) return MatchTransitionPhase.settledDefence;
      return MatchTransitionPhase.retreat;
    }
    return MatchTransitionPhase.recovery;
  }

  static MatchTransitionProfile fromStyle(String style, MatchTransitionPhase phase) {
    final base = switch (style) {
      'high_press' => const (line: .80, compact: .88, cover: .82, track: .90, press: 1.30, retreat: .72),
      'low_block' => const (line: .28, compact: .94, cover: .96, track: .96, press: .62, retreat: .90),
      'counter' => const (line: .42, compact: .78, cover: .88, track: .82, press: 1.08, retreat: .86),
      'direct' => const (line: .66, compact: .72, cover: .78, track: .78, press: .94, retreat: .76),
      'possession' => const (line: .60, compact: .82, cover: .84, track: .82, press: .92, retreat: .78),
      'wing' => const (line: .62, compact: .70, cover: .76, track: .78, press: .96, retreat: .76),
      _ => const (line: .60, compact: .78, cover: .82, track: .80, press: 1.0, retreat: .78),
    };
    switch (phase) {
      case MatchTransitionPhase.inPossession:
        return MatchTransitionProfile(phase: phase, lineHeight: base.line, compactness: base.compact, cover: base.cover, runnerTracking: base.track, counterPress: base.press, retreatSpeed: base.retreat);
      case MatchTransitionPhase.loss:
        return MatchTransitionProfile(phase: phase, lineHeight: base.line + .04, compactness: base.compact + .03, cover: base.cover, runnerTracking: base.track, counterPress: base.press * 1.15, retreatSpeed: base.retreat);
      case MatchTransitionPhase.counterPress:
        return MatchTransitionProfile(phase: phase, lineHeight: min(1.0, base.line + .08), compactness: base.compact + .06, cover: base.cover, runnerTracking: base.track * .94, counterPress: base.press * 1.22, retreatSpeed: base.retreat * .88);
      case MatchTransitionPhase.retreat:
        return MatchTransitionProfile(phase: phase, lineHeight: max(.15, base.line - .12), compactness: base.compact + .08, cover: base.cover + .05, runnerTracking: base.track + .06, counterPress: base.press * .78, retreatSpeed: base.retreat * 1.16);
      case MatchTransitionPhase.settledDefence:
        return MatchTransitionProfile(phase: phase, lineHeight: base.line, compactness: min(1.0, base.compact + .12), cover: min(1.0, base.cover + .08), runnerTracking: min(1.0, base.track + .08), counterPress: base.press * .82, retreatSpeed: base.retreat);
      case MatchTransitionPhase.recovery:
        return MatchTransitionProfile(phase: phase, lineHeight: base.line, compactness: base.compact, cover: base.cover, runnerTracking: base.track, counterPress: base.press * .90, retreatSpeed: base.retreat);
    }
  }

  static double _nearestDistance(Match2DState state, Match2DTeam team, Match2DPlayer owner) {
    var best = double.infinity;
    for (final p in state.players) {
      if (!p.active || p.team != team) continue;
      final dx = p.x - owner.x;
      final dy = p.y - owner.y;
      final d = (dx * dx + dy * dy);
      if (d < best) best = d;
    }
    return best.isFinite ? sqrt(best) : 99;
  }
}

