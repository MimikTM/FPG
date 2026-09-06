import 'player_role.dart';

enum AttackingRunType { depth, channel, overlap, underlap, support, decoy, recovery }

class AttackingRunDecision {
  final AttackingRunType type;
  final double targetX;
  final double targetY;
  final double intensity;
  final double separation;
  final PlayerRole role;

  const AttackingRunDecision({
    required this.type,
    required this.targetX,
    required this.targetY,
    required this.intensity,
    required this.separation,
    required this.role,
  });
}

class AttackingRunSnapshot {
  final int homeRuns;
  final int awayRuns;
  final int homeDangerousRuns;
  final int awayDangerousRuns;
  final int homeOverlaps;
  final int awayOverlaps;
  final int homeChannelRuns;
  final int awayChannelRuns;

  const AttackingRunSnapshot({
    this.homeRuns = 0,
    this.awayRuns = 0,
    this.homeDangerousRuns = 0,
    this.awayDangerousRuns = 0,
    this.homeOverlaps = 0,
    this.awayOverlaps = 0,
    this.homeChannelRuns = 0,
    this.awayChannelRuns = 0,
  });
}
