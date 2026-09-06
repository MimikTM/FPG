import 'package:fpg/models/match_momentum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/match_2d.dart';
import 'package:fpg/simulation/match_momentum_engine.dart';

void main() {
  test('momentum remains balanced with no recent events', () {
    final players = <Match2DPlayer>[];
    final state = Match2DState(players: players, minute: 45);
    final snapshot = const MatchMomentumEngine().evaluate(state: state, events: const []);
    expect(snapshot.state, MatchMomentumState.balanced);
    expect(snapshot.home, 50);
    expect(snapshot.away, 50);
  });
}
