import 'package:flutter_test/flutter_test.dart';

import 'package:fpg/core/game_state.dart';
import 'package:fpg/models/player.dart';

void main() {
  test('calendar state round-trips and transfer windows stay deterministic', () {
    final state = GameState(year: 2026, month: 8, day: 31, season: 2026);
    final restored = GameState.fromJson(state.toJson());
    expect(restored.year, 2026);
    expect(restored.month, 8);
    expect(restored.day, 31);
    expect(restored.season, 2026);
    expect(restored.transferWindowSummer, isTrue);
    expect(restored.transferWindowWinter, isFalse);
  });

  test('shirt numbers are valid data fields on world players', () {
    final player = Player(
      id: 'beta-player',
      name: 'Beta Player',
      age: 19,
      position: PlayerPosition.midfielder,
      overall: 65,
      potential: 82,
      shirtNumber: 47,
    );
    final json = player.toJson();
    expect(json['shirtNumber'], 47);
    final restored = Player.fromJson(json);
    expect(restored.shirtNumber, 47);
  });
}
