import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/simulation/full_match_simulation.dart';

void main() {
  test('etap 78 utrzymuje kompletną symulację i telemetrykę zmian', () {
    Player p(String id, PlayerPosition position, int overall) => Player(
      id: id,
      name: id,
      position: position,
      overall: overall,
      potential: overall + 5,
      age: 20,
    );

    final squad = <Player>[
      p('gk', PlayerPosition.goalkeeper, 72),
      ...List.generate(4, (i) => p('d$i', PlayerPosition.defender, 72 - i)),
      ...List.generate(3, (i) => p('m$i', PlayerPosition.midfielder, 74 - i)),
      ...List.generate(2, (i) => p('w$i', PlayerPosition.winger, 75 - i)),
      p('st', PlayerPosition.striker, 76),
      ...List.generate(7, (i) => p('b$i', PlayerPosition.midfielder, 68 - i)),
    ];

    final result = FullMatchSimulation().run(
      home: squad,
      away: squad.map((x) => Player(
        id: 'a_${x.id}', name: 'a_${x.name}', position: x.position, overall: x.overall, potential: x.potential, age: x.age,
      )).toList(),
      gameplayResultAuthority: true,
    );

    expect(result.completed, isTrue);
    expect(result.substitutions, lessThanOrEqualTo(6));
    expect(result.scoreLedgerConsistent, isTrue);
  });
}
