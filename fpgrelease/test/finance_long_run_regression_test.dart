import 'package:flutter_test/flutter_test.dart';

import 'package:fpg/data/world_data.dart';
import 'package:fpg/models/club.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/simulation/finance_engine.dart';

void main() {
  test('season finance is applied exactly once and remains bounded', () {
    final clubs = WorldData.clubs.map((c) => Club.fromJson(c.toJson())).toList();
    final players = WorldData.players.map((p) => Player.fromJson(p.toJson())).toList();
    final engine = FinanceEngine();

    final initial = {for (final c in clubs) c.id: c.budget};

    // A deterministic one-season check catches accidental duplicate credits:
    // applying processSeason once must match the exact formula used by the engine.
    engine.processSeason(clubs);
    for (final club in clubs) {
      final before = initial[club.id]!;
      final expected = (before +
              250000 + club.overall * 18000 + club.reputation * 6000 +
              150000 + club.overall * 20000 + club.reputation * 5000 -
              (100 - club.financialHealth) * 5000)
          .clamp(0, 1 << 62);
      expect(club.budget, expected);
      expect(club.budget, greaterThanOrEqualTo(0));
      expect(club.financialHealth, inInclusiveRange(10, 100));
      expect(club.boardPressure, inInclusiveRange(0, 100));
    }

    // Repeated season processing must never produce NaN/negative financial
    // state or overflow-like behaviour.
    for (var season = 0; season < 10; season++) {
      engine.processWeekly(clubs, players);
      engine.processSeason(clubs);
    }

    for (final club in clubs) {
      expect(club.budget, greaterThanOrEqualTo(0));
      expect(club.budget, lessThan(1 << 62));
      expect(club.financialHealth, inInclusiveRange(10, 100));
      expect(club.boardPressure, inInclusiveRange(0, 100));
    }
  });
}
