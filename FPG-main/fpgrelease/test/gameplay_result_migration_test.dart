import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/simulation/gameplay_result_authority.dart';

void main() {
  test('gameplay result authority starts with an empty ledger', () {
    final authority = GameplayResultAuthority();
    final snapshot = authority.snapshot(homeGoals: 0, awayGoals: 0);
    expect(snapshot.consistent, isTrue);
  });

  test('ledger must match the final gameplay score', () {
    final authority = GameplayResultAuthority();
    authority.recordGoal(home: true);
    authority.recordGoal(home: false);
    final snapshot = authority.snapshot(homeGoals: 1, awayGoals: 1);
    expect(snapshot.consistent, isTrue);
  });

  test('wrong final score is rejected by the consistency boundary', () {
    final authority = GameplayResultAuthority();
    authority.recordGoal(home: true);
    final snapshot = authority.snapshot(homeGoals: 0, awayGoals: 0);
    expect(snapshot.consistent, isFalse);
  });
}
