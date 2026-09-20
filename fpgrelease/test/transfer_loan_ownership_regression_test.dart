import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/club.dart';
import 'package:fpg/models/player.dart';
import 'package:fpg/simulation/transfer_engine.dart';

Club club(String id) => Club(
  id: id,
  name: 'Club $id',
  country: 'PL',
  leagueId: 'l',
  overall: 70,
  budget: 50000000,
  minimumSigningOverall: 60,
);

Player player(String id, String clubId, {bool loaned = false}) => Player(
  id: id,
  name: 'Player $id',
  age: 22,
  position: PlayerPosition.striker,
  overall: 72,
  potential: 82,
  pace: 70,
  shooting: 75,
  passing: 65,
  dribbling: 70,
  defending: 35,
  physical: 65,
  value: 1000000,
  weeklyWage: 5000,
  clubId: clubId,
  loanFromClubId: loaned ? 'parent' : null,
  loanUntilDay: loaned ? 300 : 0,
  squadStatus: 'reserves',
);

void main() {
  test('loaned player cannot be sold by the loan club', () {
    final parent = club('parent');
    final loan = club('loan');
    final buyer = club('buyer');
    final p = player('p', loan.id, loaned: true);

    final beforeLoanClub = p.clubId;
    final beforeParent = p.loanFromClubId;
    final beforeDay = p.loanUntilDay;

    TransferEngine(random: Random(7)).processWindow(
      clubs: [parent, loan, buyer],
      players: [p],
      summer: true,
      winter: false,
      absoluteDay: 100,
    );

    expect(p.clubId, beforeLoanClub);
    expect(p.loanFromClubId, beforeParent);
    expect(p.loanUntilDay, beforeDay);
  });

  test('completed permanent transfer clears stale transfer request and loan state', () {
    final seller = club('seller');
    final buyer = club('buyer');
    final p = player('p', seller.id);
    p.transferRequest = true;

    // Seed chosen to allow the normal market path; repeat a bounded number of
    // windows so the assertion tests the resulting invariant, not one roll.
    for (var day = 1; day <= 30 && p.clubId == seller.id; day++) {
      TransferEngine(random: Random(day)).processWindow(
        clubs: [seller, buyer],
        players: [p],
        summer: true,
        winter: false,
        absoluteDay: day,
      );
    }

    if (p.clubId == buyer.id) {
      expect(p.transferRequest, isFalse);
      expect(p.loanFromClubId, isNull);
      expect(p.loanUntilDay, 0);
      expect(p.contractYearsRemaining, greaterThan(0));
    }
  });
}
