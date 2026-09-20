import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/club.dart';
import 'package:fpg/models/league.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/simulation/world_engine.dart';
import 'package:fpg/simulation/world_integrity_validator.dart';
import 'package:fpg/simulation/world_long_run_audit.dart';
import 'package:fpg/simulation/world_player_generator.dart';

void main() {
  test('10-season world stress keeps identity, contracts, loans and squads valid', () {
    final leagues = [
      League(id: 'top', name: 'Top', country: 'Testland', level: 1),
      League(id: 'second', name: 'Second', country: 'Testland', level: 2),
    ];
    final clubs = <Club>[];
    for (var i = 0; i < 8; i++) {
      clubs.add(Club(
        id: 'stress_club_$i',
        name: 'Stress Club $i',
        country: 'Testland',
        leagueId: i < 4 ? 'top' : 'second',
        overall: 60 + (i % 7),
        budget: 12000000,
        reputation: 55,
        financialHealth: 75,
        youthFocus: 65,
        transferActivity: 50,
      ));
    }

    final generator = WorldPlayerGenerator(random: Random(1234));
    final players = <Player>[];
    for (final club in clubs) {
      players.addAll(generator.generateFirstTeamSquad(
        year: 2026,
        club: club,
        targetSize: 22,
      ));
    }

    final world = WorldEngine(
      clubs: clubs,
      players: players,
      leagues: leagues,
      seasonStartYear: 2026,
      random: Random(5678),
    );

    for (var season = 2026; season < 2036; season++) {
      world.processEndOfSeason(nextSeasonStartYear: season + 1);
      final report = WorldIntegrityValidator.validate(clubs: clubs, players: players);
      expect(report.isValid, isTrue, reason: 'season=${season + 1}\n${report.errors.join('\n')}');

      final audit = WorldLongRunAudit.snapshot(
        seasonYear: season + 1,
        clubs: clubs,
        players: players,
      );
      WorldLongRunAudit.assertHealthy(audit);

      // Every player with a club must exist in exactly that club roster.
      for (final player in players.where((p) => p.clubId != null)) {
        final owners = clubs.where((c) => c.playerIds.contains(player.id)).toList();
        expect(owners, hasLength(1), reason: 'player=${player.id} season=${season + 1}');
        expect(owners.single.id, player.clubId);
      }

      // No club may silently lose the ability to field a first team.
      for (final club in clubs) {
        final senior = players.where((p) =>
            p.clubId == club.id &&
            p.squadStatus != 'academy' &&
            p.squadStatus != 'freeAgent').length;
        expect(senior, greaterThanOrEqualTo(18), reason: 'club=${club.id} season=${season + 1}');
      }

      // Expired professional contracts must never survive as an invalid
      // zero-year contract attached to a club.
      expect(
        players.where((p) => p.clubId != null && p.hasProfessionalContract && p.contractYearsRemaining <= 0),
        isEmpty,
      );
    }
  });
}
