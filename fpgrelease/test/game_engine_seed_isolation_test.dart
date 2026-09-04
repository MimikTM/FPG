
import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/core/game_engine.dart';
import 'package:fpg/core/game_state.dart';

void main() {
  test('each GameEngine owns an isolated mutable world seed', () {
    final first = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );
    final originalBudget = first.clubs.first.budget;
    final originalManager = first.clubs.first.managerName;
    final originalPlayerAge = first.players.first.age;

    first.clubs.first.budget = 1;
    first.clubs.first.managerName = 'MUTATED_TEST_MANAGER';
    first.players.first.age = 99;

    final second = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );

    expect(second.clubs.first.budget, originalBudget);
    expect(second.clubs.first.managerName, originalManager);
    expect(second.players.first.age, originalPlayerAge);
    expect(identical(first.clubs.first, second.clubs.first), isFalse);
    expect(identical(first.players.first, second.players.first), isFalse);
    expect(identical(first.leagues.first, second.leagues.first), isFalse);
  });

  test('mutating one engine does not change WorldData seed for later engines', () {
    final engine = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );
    final club = engine.clubs.first;
    final player = engine.players.first;

    club.financialHealth = 3;
    club.leagueId = 'mutated_league';
    player.clubId = null;
    player.squadStatus = 'freeAgent';

    final fresh = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );
    final freshClub = fresh.clubs.first;
    final freshPlayer = fresh.players.first;

    expect(freshClub.leagueId, 'pol_ek');
    expect(freshClub.financialHealth, greaterThan(3));
    expect(freshPlayer.clubId, isNotNull);
    expect(freshPlayer.squadStatus, isNot('freeAgent'));
  });
}
