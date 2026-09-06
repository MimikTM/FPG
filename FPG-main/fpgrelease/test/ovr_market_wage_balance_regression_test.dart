import 'package:flutter_test/flutter_test.dart';

import 'package:fpg/models/club.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/simulation/development_engine.dart';
import 'package:fpg/simulation/market_value_engine.dart';

void main() {
  test('development changes market value without silently rewriting wage', () {
    final player = Player(
      id: 'balance_player',
      name: 'Balance Player',
      age: 21,
      position: PlayerPosition.midfielder,
      overall: 70,
      potential: 85,
      pace: 70,
      shooting: 65,
      passing: 74,
      dribbling: 72,
      defending: 60,
      physical: 68,
      value: 8000000,
      weeklyWage: 12000,
      clubId: 'club_1',
      contractYearsRemaining: 3,
      hasProfessionalContract: true,
      fitness: 100,
      morale: 90,
      form: 90,
    );
    final club = Club(
      id: 'club_1',
      name: 'Test FC',
      country: 'Polska',
      leagueId: 'test',
      overall: 70,
      budget: 30000000,
    );

    final beforeWage = player.weeklyWage;
    DevelopmentEngine().processDay([player], [club]);

    expect(player.weeklyWage, beforeWage);
    expect(player.value, greaterThan(0));
    expect(player.overall, lessThanOrEqualTo(player.potential));
  });

  test('market value engine is the same valuation source used after development', () {
    final player = Player(
      id: 'value_player',
      name: 'Value Player',
      age: 24,
      position: PlayerPosition.striker,
      overall: 78,
      potential: 88,
      pace: 80,
      shooting: 82,
      passing: 65,
      dribbling: 76,
      defending: 35,
      physical: 72,
      value: 1,
      weeklyWage: 15000,
      clubId: 'club_1',
      contractYearsRemaining: 3,
      hasProfessionalContract: true,
    );

    final engine = MarketValueEngine();
    engine.refreshWorldPlayer(player);
    final expected = player.value;
    expect(expected, greaterThan(50000));

    engine.refreshWorldPlayer(player);
    expect(player.value, expected);
  });
}
