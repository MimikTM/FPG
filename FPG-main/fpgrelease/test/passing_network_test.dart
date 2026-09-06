import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/match_passing_network.dart';

void main() {
  test('passing tracker measures progressive passing and sequences', () {
    final tracker = PassingNetworkTracker()..reset();
    tracker.possessionStarted(true);
    tracker.pass(home: true, distance: 12, forwardProgress: 9, targetY: 50);
    tracker.pass(home: true, distance: 8, forwardProgress: 3, targetY: 15);
    tracker.finalThirdEntry(true);
    tracker.turnover(true);
    final s = tracker.homeSnapshot();
    expect(s.possessions, 1);
    expect(s.completedPasses, 2);
    expect(s.progressivePasses, 1);
    expect(s.finalThirdEntries, 1);
    expect(s.longestSequence, 3);
    expect(s.averagePassDistance, 10);
    expect(s.widthUsage, .5);
  });
}
