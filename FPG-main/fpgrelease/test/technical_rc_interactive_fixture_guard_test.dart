import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/core/game_engine.dart';
import 'package:fpg/core/game_state.dart';

void main() {
  test('interactive fixture rejects an invalid score before mutation', () {
    final engine = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );
    final fixture = engine.fixtures.first;

    expect(
      () => engine.reconcileInteractiveFixtureResult(
        fixture: fixture,
        finalHomeGoals: -1,
        finalAwayGoals: 0,
      ),
      throwsArgumentError,
    );
    expect(fixture.played, isFalse);
  });
}
