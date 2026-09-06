import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/simulation/shadow_match_benchmark.dart';

List<Player> _squad(String prefix, String clubId, int base) => [
  Player(id: '${prefix}gk', name: '${prefix} GK', age: 24, position: PlayerPosition.goalkeeper, nationality: 'PL', overall: base, potential: base + 5, pace: 50, shooting: 20, passing: 60, dribbling: 30, defending: 70, physical: 70, clubId: clubId, shirtNumber: 1),
  ...List.generate(5, (i) => Player(id: '$prefix-d$i', name: '$prefix D$i', age: 24, position: PlayerPosition.defender, nationality: 'PL', overall: base, potential: base + 5, pace: 62, shooting: 35, passing: 58, dribbling: 42, defending: 72, physical: 72, clubId: clubId, shirtNumber: 2 + i)),
  ...List.generate(4, (i) => Player(id: '$prefix-m$i', name: '$prefix M$i', age: 24, position: PlayerPosition.midfielder, nationality: 'PL', overall: base, potential: base + 5, pace: 68, shooting: 55, passing: 72, dribbling: 65, defending: 55, physical: 65, clubId: clubId, shirtNumber: 7 + i)),
  ...List.generate(3, (i) => Player(id: '$prefix-w$i', name: '$prefix W$i', age: 24, position: PlayerPosition.winger, nationality: 'PL', overall: base, potential: base + 5, pace: 78, shooting: 65, passing: 68, dribbling: 76, defending: 35, physical: 60, clubId: clubId, shirtNumber: 11 + i)),
  Player(id: '$prefix-st', name: '$prefix ST', age: 24, position: PlayerPosition.striker, nationality: 'PL', overall: base + 2, potential: base + 7, pace: 76, shooting: 82, passing: 55, dribbling: 70, defending: 25, physical: 75, clubId: clubId, shirtNumber: 9),
];

void main() {
  test('shadow benchmark covers style matrix and preserves authority consistency', () {
    final report = ShadowMatchBenchmark(matchesPerPair: 1, seed: 70069).run(
      home: _squad('H', 'home', 70),
      away: _squad('A', 'away', 69),
    );

    expect(report.matches, 49);
    expect(report.infrastructureGatePassed, isTrue);
    expect(report.ledgerConsistencyRate, 1.0);
    expect(report.completionRate, 1.0);
    expect(report.totalShots, greaterThanOrEqualTo(0));
    expect(report.totalGoals, greaterThanOrEqualTo(0));
  });

  test('benchmark seed stream is deterministic for the same matrix', () {
    final home = _squad('H', 'home', 72);
    final away = _squad('A', 'away', 72);
    final a = ShadowMatchBenchmark(matchesPerPair: 1, seed: 70100).run(home: home, away: away);
    final b = ShadowMatchBenchmark(matchesPerPair: 1, seed: 70100).run(
      home: _squad('H', 'home', 72),
      away: _squad('A', 'away', 72),
    );

    expect(a.totalGoals, b.totalGoals);
    expect(a.totalShots, b.totalShots);
    expect(a.totalFouls, b.totalFouls);
    expect(a.totalCards, b.totalCards);
    expect(a.totalCorners, b.totalCorners);
    expect(a.totalSubstitutions, b.totalSubstitutions);
  });
}
