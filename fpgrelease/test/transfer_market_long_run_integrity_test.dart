import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/club.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/simulation/transfer_engine.dart';
import 'package:fpg/simulation/world_integrity_validator.dart';

Club _club(String id, int index) => Club(
      id: id,
      name: 'Test Club $index',
      country: 'PL',
      leagueId: 'test',
      overall: 62 + (index % 5),
      reputation: 55 + (index % 6) * 5,
      budget: 45000000,
      financialHealth: 70,
      minimumSigningOverall: 58,
      transferActivity: 55 + (index % 4) * 10,
      preferredMinAge: 18,
      preferredMaxAge: 30,
      youthFocus: 50 + (index % 5) * 8,
    );

Player _player(String id, String clubId, int index) {
  final positions = PlayerPosition.values;
  final position = positions[index % positions.length];
  final overall = 58 + (index % 18);
  return Player(
    id: id,
    name: 'Test Player $id',
    age: 18 + (index % 14),
    position: position,
    nationality: 'PL',
    overall: overall,
    potential: min(90, overall + 8 + (index % 8)),
    pace: 55 + (index % 30),
    shooting: 50 + (index % 35),
    passing: 50 + (index % 35),
    dribbling: 50 + (index % 35),
    defending: 45 + (index % 40),
    physical: 50 + (index % 35),
    value: 350000 + (index % 20) * 100000,
    weeklyWage: 700 + (index % 15) * 250,
    clubId: clubId,
    contractYearsRemaining: 1 + (index % 4),
    hasProfessionalContract: true,
    squadStatus: index % 11 == 0 ? 'reserves' : 'squad',
    form: 65 + (index % 11),
    morale: 60 + (index % 20),
  );
}

void _assertHealthy(List<Club> clubs, List<Player> players, String phase) {
  final report = WorldIntegrityValidator.validate(clubs: clubs, players: players);
  expect(report.isValid, isTrue, reason: '$phase\n${report.errors.join('\n')}');

  final playerById = {for (final p in players) p.id: p};
  for (final club in clubs) {
    expect(club.playerIds.toSet().length, club.playerIds.length,
        reason: 'duplicate roster: ${club.id}');
    for (final id in club.playerIds) {
      final player = playerById[id];
      expect(player, isNotNull, reason: 'unknown roster player $id');
      expect(player!.clubId, club.id,
          reason: 'ownership mismatch for $id at ${club.id}');
    }
  }
}

void main() {
  test('transfer market remains structurally valid across 10 seasons', () {
    final clubs = List.generate(10, (i) => _club('c$i', i));
    final players = <Player>[];
    var n = 0;
    for (final club in clubs) {
      // Enough depth to allow transfers without making a seller collapse.
      for (var i = 0; i < 24; i++) {
        players.add(_player('p${n++}', club.id, n));
      }
    }

    // Add a small free-agent pool so both market branches are exercised.
    for (var i = 0; i < 20; i++) {
      final p = _player('fa${i}', clubs[i % clubs.length].id, n++);
      p.clubId = null;
      p.contractYearsRemaining = 0;
      p.hasProfessionalContract = false;
      p.squadStatus = 'freeAgent';
      players.add(p);
    }

    final engine = TransferEngine(random: Random(20260828));
    _assertHealthy(clubs, players, 'initial state');

    // Two transfer windows per season. The absolute day is monotonic so loan
    // returns are tested against the same clock used by WorldEngine.
    for (var season = 0; season < 10; season++) {
      final summerDay = 365 * season + 10;
      final winterDay = summerDay + 180;

      engine.processLoanReturns(
        clubs: clubs,
        players: players,
        absoluteDay: summerDay,
      );
      engine.processWindow(
        clubs: clubs,
        players: players,
        summer: true,
        winter: false,
        absoluteDay: summerDay,
      );
      _assertHealthy(clubs, players, 'after summer window season $season');

      engine.processLoanReturns(
        clubs: clubs,
        players: players,
        absoluteDay: winterDay,
      );
      engine.processWindow(
        clubs: clubs,
        players: players,
        summer: false,
        winter: true,
        absoluteDay: winterDay,
      );
      _assertHealthy(clubs, players, 'after winter window season $season');

      // Exercise a later loan-return tick without opening another window.
      engine.processLoanReturns(
        clubs: clubs,
        players: players,
        absoluteDay: winterDay + 360,
      );
      _assertHealthy(clubs, players, 'after loan returns season $season');
    }

    expect(players.map((p) => p.id).toSet().length, players.length);
    expect(clubs.every((c) => c.playerIds.length >= 19), isTrue);
    expect(players.where((p) => p.loanFromClubId != null).every((p) =>
        p.clubId != null && p.loanFromClubId != p.clubId && p.loanUntilDay > 0), isTrue);
  });

  test('loaned players never become permanent transfer targets', () {
    final seller = _club('seller', 1);
    final buyer = _club('buyer', 2);
    final players = <Player>[];

    for (var i = 0; i < 24; i++) {
      players.add(_player('s$i', seller.id, i));
      players.add(_player('b$i', buyer.id, i + 100));
    }

    final loaned = players.first;
    loaned.loanFromClubId = seller.id;
    loaned.loanUntilDay = 500;
    loaned.clubId = buyer.id;

    final engine = TransferEngine(random: Random(9));
    for (var day = 1; day < 500; day += 30) {
      engine.processWindow(
        clubs: [seller, buyer],
        players: players,
        summer: day == 1,
        winter: day == 181,
        absoluteDay: day,
      );
      expect(loaned.clubId, buyer.id);
      expect(loaned.loanFromClubId, seller.id);
      expect(loaned.loanUntilDay, 500);
    }

    engine.processLoanReturns(
      clubs: [seller, buyer],
      players: players,
      absoluteDay: 500,
    );
    expect(loaned.clubId, seller.id);
    expect(loaned.loanFromClubId, isNull);
    expect(loaned.loanUntilDay, 0);
  });
}
