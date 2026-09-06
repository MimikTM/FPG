import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fpg/models/club.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/simulation/squad_depth_engine.dart';
import 'package:fpg/simulation/world_player_generator.dart';

void main() {
  test('P1.1 squad depth keeps a club at playable minimum after retirements', () {
    final club = Club(
      id: 'c1',
      name: 'Test FC',
      country: 'Polska',
      leagueId: 'l1',
      overall: 70,
      budget: 10000000,
    );
    final generator = WorldPlayerGenerator(random: math.Random(12345));
    final players = generator.generateFirstTeamSquad(
      year: 2027,
      club: club,
      targetSize: 15,
    );
    for (final p in players) {
      p.squadStatus = 'reserves';
    }

    final created = SquadDepthEngine.ensureMinimumSeniorSquads(
      clubs: [club],
      players: players,
      generator: generator,
      seasonYear: 2027,
    );

    expect(created, isNotEmpty);
    expect(
      players.where((p) => p.clubId == club.id && p.squadStatus != 'academy' && p.squadStatus != 'freeAgent').length,
      greaterThanOrEqualTo(SquadDepthEngine.minimumSeniorSquad),
    );
  });
  test('P1.1 generated senior squad players are professional, not academy prospects', () {
    final club = Club(
      id: 'c2',
      name: 'Senior FC',
      country: 'Polska',
      leagueId: 'l1',
      overall: 70,
      budget: 10000000,
    );
    final generator = WorldPlayerGenerator(random: math.Random(54321));
    final players = generator.generateFirstTeamSquad(
      year: 2027,
      club: club,
      targetSize: 20,
    );

    expect(players.every((p) => p.hasProfessionalContract), isTrue);
    expect(players.every((p) => p.squadStatus != 'academy'), isTrue);
  });

}
