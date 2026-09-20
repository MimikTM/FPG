import '../models/team_play_style.dart';

/// Phase 6 / 73: conservative gameplay tuning constants.
///
/// This layer deliberately changes only emergent chance quality. It does not
/// touch fixture results, league reconciliation, saves, or career state.
class GameplayTuning {
  const GameplayTuning._();

  /// Strength gap is intentionally a soft multiplier rather than a hard win
  /// bias. A 20-point team-quality gap changes chance quality by only ~5%.
  static double strengthChanceModifier({
    required double attackingStrength,
    required double defendingStrength,
  }) {
    final gap = ((attackingStrength - defendingStrength) / 100).clamp(-.30, .30);
    return (1 + gap * .25).clamp(.90, 1.10);
  }

  /// Small style identity modifiers complement the existing movement,
  /// transition and decision systems without replacing them.
  static double styleChanceModifier(String managerStyle) {
    return switch (TeamPlayStyleProfile.fromManagerStyle(managerStyle).style) {
      TeamPlayStyle.possession => .99,
      TeamPlayStyle.direct => 1.03,
      TeamPlayStyle.counter => 1.04,
      TeamPlayStyle.wingPlay => 1.02,
      TeamPlayStyle.highPress => 1.02,
      TeamPlayStyle.lowBlock => .94,
      TeamPlayStyle.balanced => 1.00,
    };
  }

  static double combinedChanceModifier({
    required double attackingStrength,
    required double defendingStrength,
    required String managerStyle,
  }) {
    return (strengthChanceModifier(
              attackingStrength: attackingStrength,
              defendingStrength: defendingStrength,
            ) *
            styleChanceModifier(managerStyle))
        .clamp(.84, 1.14);
  }
}
