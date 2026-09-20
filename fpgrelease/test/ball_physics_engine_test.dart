import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/simulation/ball_physics_engine.dart';
import 'package:fpg/models/match_2d.dart';
import 'package:fpg/models/player_role.dart';
import 'package:fpg/models/player.dart';

Match2DPlayer player(String id, {PlayerPosition position = PlayerPosition.midfielder, int passing = 80}) => Match2DPlayer(
  id: id, name: id, position: position, role: PlayerRole.playmaker,
  team: Match2DTeam.home, x: 20, y: 50, shirtNumber: 8, overall: 80,
  passing: passing, dribbling: 80, shooting: 70, pace: 70, defending: 50, physical: 65,
);

void main() {
  test('long pass gets a distinct lofted flight', () {
    const engine = BallPhysicsEngine();
    final launch = engine.launch(passer: player('a'), target: player('b'), distance: 30);
    expect(launch.type, BallPassType.lofted);
    expect(launch.peakHeight, greaterThan(0));
    final flight = engine.sample(startX: 20, startY: 50, endX: 50, endY: 50, progress: .5, launch: launch);
    expect(flight.x, closeTo(35, .1));
    expect(flight.height, greaterThan(0));
  });

  test('wing cross carries extra spin', () {
    const engine = BallPhysicsEngine();
    final launch = engine.launch(passer: player('w', position: PlayerPosition.winger), target: player('b'), distance: 22, cross: true);
    expect(launch.type, BallPassType.cross);
    expect(launch.spin, greaterThan(1));
  });

  test('loose ball loses speed and stays inside pitch', () {
    const engine = BallPhysicsEngine();
    final next = engine.stepLoose(x: 50, y: 50, velocityX: 10, velocityY: -4, spin: 2, bounce: .8);
    expect(next.x, greaterThan(50));
    expect(next.velocityX.abs(), lessThan(10));
    expect(next.y, lessThan(50));
    expect(next.x, inInclusiveRange(2.5, 97.5));
  });
}
