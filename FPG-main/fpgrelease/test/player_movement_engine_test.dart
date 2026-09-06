import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/match_2d.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/models/player_role.dart';
import 'package:fpg/simulation/player_movement_engine.dart';

Match2DPlayer player({int pace = 80, int stamina = 100}) => Match2DPlayer(
  id: 'p', name: 'P', position: PlayerPosition.midfielder,
  role: PlayerRole.boxToBox, team: Match2DTeam.home, x: 30, y: 50,
  shirtNumber: 8, overall: 75, pace: pace, stamina: stamina,
);

void main() {
  test('movement accelerates and decelerates instead of teleporting', () {
    const engine = PlayerMovementEngine();
    final p = player();
    engine.apply(p, 70, 50, urgency: 1.0);
    expect(p.x, greaterThan(30));
    final firstSpeed = sqrt(p.velocityX * p.velocityX + p.velocityY * p.velocityY);
    engine.stop(p);
    expect(p.velocityX, lessThan(firstSpeed));
  });

  test('pace changes top movement response', () {
    const engine = PlayerMovementEngine();
    final slow = player(pace: 45);
    final fast = player(pace: 95);
    engine.apply(slow, 70, 50, urgency: 1.0);
    engine.apply(fast, 70, 50, urgency: 1.0);
    final slowSpeed = sqrt(slow.velocityX * slow.velocityX + slow.velocityY * slow.velocityY);
    final fastSpeed = sqrt(fast.velocityX * fast.velocityX + fast.velocityY * fast.velocityY);
    expect(fastSpeed, greaterThan(slowSpeed));
  });
}
