import 'dart:math';
import '../models/club.dart';
import '../models/player.dart';
import '../models/loan_negotiation.dart';

class LoanNegotiationEngine {
  final Random _random;
  final Map<String, LoanNegotiation> active = {};
  LoanNegotiationEngine({Random? random}) : _random = random ?? Random();

  List<String> process({required List<Club> clubs, required List<Player> players, required bool transferWindow, int absoluteDay = 0}) {
    if (!transferWindow) return [];
    final logs = <String>[];
    final candidates = players.where((p) => p.clubId != null && (p.squadStatus == 'reserves' || p.squadStatus == 'outOfSquad' || p.consecutiveBenchDays >= 14) && p.age <= 24).toList();
    for (final player in candidates.take(max(1, clubs.length ~/ 8))) {
      final parent = clubs.firstWhereOrNull((c) => c.id == player.clubId);
      if (parent == null) continue;
      final destination = clubs.firstWhereOrNull((c) => c.id != parent.id && c.overall >= player.overall - 12 && c.overall <= player.overall + 4 && c.financialHealth > 30);
      if (destination == null) continue;
      final id = '${parent.id}::${destination.id}::${player.id}';
      final n = active.putIfAbsent(id, () => LoanNegotiation(
        id: id,
        parentClubId: parent.id,
        destinationClubId: destination.id,
        playerId: player.id,
        loanFee: max(25000, (player.value * .03).round()),
        wageShare: .55,
        guaranteedMinutes: 900,
        buyoutClause: player.value * 1.8,
      ));
      n.round++;
      if (n.round >= 2 && _random.nextDouble() < .45) {
        if (destination.budget >= n.loanFee && destination.overall <= player.overall + 6) {
          destination.budget -= n.loanFee;
          parent.budget += n.loanFee;
          player.loanFromClubId = parent.id;
          player.clubId = destination.id;
          // Loan duration is absolute in the world clock.
          player.loanUntilDay = absoluteDay + 180;
          player.loanStartedDay = absoluteDay;
          player.loanStartMinutes = player.minutesPlayed;
          player.loanWageShare = n.wageShare.clamp(0.0, 1.0);
          player.loanBuyoutClause = n.buyoutClause;
          player.loanFeePaid = n.loanFee.toDouble();
          player.loanFeeExpectation = n.loanFee.toDouble();
          player.guaranteedMinutesExpectation = n.guaranteedMinutes;
          player.buyoutClauseExpectation = n.buyoutClause;

          player.happiness = min(100, player.happiness + 8);
          n.stage = 'accepted';
          active.remove(id);
          logs.add('WYPOŻYCZENIE: ${player.name} → ${destination.name} (gwarantowane minuty: ${n.guaranteedMinutes})');
          continue;
        }
      }
      if (n.round >= 4) {
        n.stage = 'rejected';
        active.remove(id);
      } else {
        n.loanFee = (n.loanFee * 1.08).round();
        n.guaranteedMinutes = min(1600, n.guaranteedMinutes + 150);
        n.stage = 'counter';
      }
    }
    return logs;
  }

  /// Charges the destination club for its contracted share of weekly wages.
  /// The parent club receives the remainder, so a loan never silently erases
  /// the player's salary obligation.
  List<String> settleDailyWages({required List<Club> clubs, required List<Player> players}) {
    final logs = <String>[];
    for (final player in players) {
      if (player.loanFromClubId == null || player.clubId == null || player.loanWageShare <= 0) continue;
      final parent = clubs.firstWhereOrNull((c) => c.id == player.loanFromClubId);
      final destination = clubs.firstWhereOrNull((c) => c.id == player.clubId);
      if (parent == null || destination == null) continue;
      final daily = max(0.0, player.weeklyWage / 7);
      final destinationPart = daily * player.loanWageShare;
      final parentPart = daily - destinationPart;
      destination.budget = max(0, destination.budget - destinationPart.round());
      parent.budget += parentPart.round();
    }
    return logs;
  }

  /// Executes an optional buyout at the agreed clause. Returns false when the
  /// clause is absent, the clubs are invalid, or the destination cannot pay.
  bool exerciseBuyout({required List<Club> clubs, required Player player}) {
    if (player.loanFromClubId == null || player.clubId == null || player.loanBuyoutClause <= 0) return false;
    final parent = clubs.firstWhereOrNull((c) => c.id == player.loanFromClubId);
    final destination = clubs.firstWhereOrNull((c) => c.id == player.clubId);
    if (parent == null || destination == null || destination.budget < player.loanBuyoutClause) return false;
    destination.budget -= player.loanBuyoutClause.round();
    parent.budget += player.loanBuyoutClause.round();
    player.loanFromClubId = null;
    player.loanUntilDay = 0;
    player.loanStartedDay = 0;
    player.loanStartMinutes = 0;
    player.loanWageShare = 0;
    player.loanBuyoutClause = 0;
    player.loanFeePaid = 0;
    player.loanFeeExpectation = 0;
    player.guaranteedMinutesExpectation = 0;
    player.buyoutClauseExpectation = 0;
    return true;
  }

  /// Enforces the contractual promise of regular minutes. The target is
  /// pro-rated over the loan, and the destination is warned/penalised when
  /// it falls materially behind schedule. This does not magically grant
  /// minutes; it feeds the player's morale/manager relationship and squad
  /// status so the existing squad AI has a reason to react.
  List<String> monitorActiveLoans({
    required List<Club> clubs,
    required List<Player> players,
    required int absoluteDay,
  }) {
    final logs = <String>[];
    for (final player in players) {
      final parentId = player.loanFromClubId;
      if (parentId == null || player.loanUntilDay <= absoluteDay ||
          player.loanStartedDay <= 0 || player.guaranteedMinutesExpectation <= 0) {
        continue;
      }
      final duration = max(1, player.loanUntilDay - player.loanStartedDay);
      final elapsed = (absoluteDay - player.loanStartedDay).clamp(0, duration);
      final expected = player.guaranteedMinutesExpectation * elapsed / duration;
      final earned = max(0, player.minutesPlayed - player.loanStartMinutes);
      final tolerance = max(90.0, player.guaranteedMinutesExpectation * .10);
      final behind = expected - earned;
      if (elapsed >= 30 && behind > tolerance) {
        player.morale = max(15, player.morale - 1);
        player.managerRelationship = max(0, player.managerRelationship - 1);
        if (player.squadStatus == 'outOfSquad' || player.squadStatus == 'reserves') {
          player.squadStatus = 'substitute';
        }
        if (elapsed % 14 == 0) {
          final destination = clubs.firstWhereOrNull((c) => c.id == player.clubId);
          logs.add('WYPOŻYCZENIE: ${player.name} jest ${behind.round()} min poniżej gwarancji w ${destination?.name ?? 'klubie docelowym'}.');
        }
      }
    }
    return logs;
  }
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) { for (final x in this) { if (test(x)) return x; } return null; }
}
