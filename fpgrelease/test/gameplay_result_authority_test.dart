import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/simulation/gameplay_result_authority.dart';

void main() {

  test('gameplay result authority records emergent goals without fixture data', () {
    final authority = GameplayResultAuthority();
    authority.recordGoal(home: true);
    authority.recordGoal(home: false);
    authority.recordGoal(home: true);

    final snapshot = authority.snapshot(homeGoals: 2, awayGoals: 1);
    expect(snapshot.consistent, isTrue);
    expect(snapshot.ledgerHomeGoals, 2);
    expect(snapshot.ledgerAwayGoals, 1);
  });
}
