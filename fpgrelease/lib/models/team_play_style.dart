/// Tactical identity used by the live match layer.
/// The club remains the owner of `managerStyle`; this is only its read-only interpretation.
enum TeamPlayStyle { possession, direct, counter, wingPlay, highPress, lowBlock, balanced }

class TeamPlayStyleProfile {
  final TeamPlayStyle style;
  final double tempo, width, forwardRisk, pressing, defensiveDepth, supportDistance;
  const TeamPlayStyleProfile({required this.style, required this.tempo, required this.width, required this.forwardRisk, required this.pressing, required this.defensiveDepth, required this.supportDistance});

  static TeamPlayStyleProfile fromManagerStyle(String value) {
    final style = switch (value.toLowerCase()) {
      'possession' => TeamPlayStyle.possession,
      'direct' => TeamPlayStyle.direct,
      'counter' => TeamPlayStyle.counter,
      'wing' || 'wing_play' || 'wingplay' => TeamPlayStyle.wingPlay,
      'high_press' || 'highpress' || 'pressing' => TeamPlayStyle.highPress,
      'low_block' || 'lowblock' => TeamPlayStyle.lowBlock,
      // Legacy manager identities are translated into football behaviours.
      'youth' => TeamPlayStyle.possession,
      'stars' => TeamPlayStyle.highPress,
      'physical' => TeamPlayStyle.direct,
      _ => TeamPlayStyle.balanced,
    };
    return fromStyle(style);
  }

  static TeamPlayStyleProfile fromStyle(TeamPlayStyle style) => switch (style) {
    TeamPlayStyle.possession => const TeamPlayStyleProfile(style: TeamPlayStyle.possession, tempo: .82, width: 1.00, forwardRisk: .82, pressing: .92, defensiveDepth: .58, supportDistance: .82),
    TeamPlayStyle.direct => const TeamPlayStyleProfile(style: TeamPlayStyle.direct, tempo: 1.16, width: .94, forwardRisk: 1.18, pressing: .96, defensiveDepth: .66, supportDistance: 1.12),
    TeamPlayStyle.counter => const TeamPlayStyleProfile(style: TeamPlayStyle.counter, tempo: 1.08, width: .98, forwardRisk: 1.22, pressing: 1.04, defensiveDepth: .48, supportDistance: 1.08),
    TeamPlayStyle.wingPlay => const TeamPlayStyleProfile(style: TeamPlayStyle.wingPlay, tempo: 1.00, width: 1.28, forwardRisk: 1.08, pressing: .98, defensiveDepth: .62, supportDistance: 1.00),
    TeamPlayStyle.highPress => const TeamPlayStyleProfile(style: TeamPlayStyle.highPress, tempo: 1.08, width: 1.04, forwardRisk: 1.08, pressing: 1.32, defensiveDepth: .78, supportDistance: .94),
    TeamPlayStyle.lowBlock => const TeamPlayStyleProfile(style: TeamPlayStyle.lowBlock, tempo: .74, width: .90, forwardRisk: .64, pressing: .70, defensiveDepth: .30, supportDistance: .72),
    TeamPlayStyle.balanced => const TeamPlayStyleProfile(style: TeamPlayStyle.balanced, tempo: 1.00, width: 1.00, forwardRisk: 1.00, pressing: 1.00, defensiveDepth: .62, supportDistance: 1.00),
  };
}
