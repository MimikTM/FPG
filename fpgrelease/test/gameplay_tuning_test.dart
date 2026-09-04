import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/simulation/gameplay_tuning.dart';

void main() {
  test('stronger attacking team receives a positive soft chance modifier', () {
    final strong = GameplayTuning.combinedChanceModifier(
      attackingStrength: 82,
      defendingStrength: 58,
      managerStyle: 'balanced',
    );
    final weak = GameplayTuning.combinedChanceModifier(
      attackingStrength: 58,
      defendingStrength: 82,
      managerStyle: 'balanced',
    );
    expect(strong, greaterThan(weak));
    expect(strong, lessThanOrEqualTo(1.14));
  });

  test('styles remain meaningfully but conservatively differentiated', () {
    expect(GameplayTuning.styleChanceModifier('low_block'), lessThan(1));
    expect(GameplayTuning.styleChanceModifier('counter'), greaterThan(1));
  });
}
