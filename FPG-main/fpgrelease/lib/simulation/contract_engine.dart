import 'dart:math';

import '../models/club.dart';
import '../models/player.dart';

/// Obsługa kontraktów świata AI bez wymagania osobnego kontraktu na każdym
/// obiekcie Player. Dane kontraktowe są obecnie reprezentowane przez płacę,
/// wartość i status zawodnika; później można podłączyć PlayerContract.
class ContractEngine {
  final Random _random;
  ContractEngine({Random? random}) : _random = random ?? Random();

  void processSeason(List<Club> clubs, List<Player> players) {
    for (final player in players) {
      final clubId = player.clubId;
      if (clubId == null) continue;
      final club = clubs.where((c) => c.id == clubId).firstOrNull;
      // A corrupted save must never make us apply one club's contract policy
      // to a player belonging to another/missing club. The integrity pass will
      // report the orphan separately.
      if (club == null) continue;

      // Każdy kontrakt naturalnie zbliża się do końca. Klub zaczyna
      // reagować wcześniej, zamiast magicznie odnawiać wszystkich.
      if (player.contractYearsRemaining > 0) {
        player.contractYearsRemaining--;
      }

      // Kontrakt wygasł: nie wolno pozostawić zawodnika w klubie z
      // kontraktem 0 lat. Jeśli klub chce go zatrzymać, próbujemy od razu
      // odnowić umowę. Gdy negocjacja odnowienia się nie powiedzie,
      // zawodnik przechodzi na rynek wolnych agentów jeszcze w tym samym
      // ticku sezonowym.
      if (player.contractYearsRemaining <= 0) {
        if (!wantsToKeep(club, player)) {
          _releasePlayer(player);
          continue;
        }

        final renewalChance = player.overall >= club.minimumSigningOverall
            ? 0.82
            : player.overall >= club.minimumSigningOverall - 5 ? 0.58 : 0.22;
        if (_random.nextDouble() < renewalChance) {
          player.contractYearsRemaining = player.age >= 30 ? 1 : 2 + _random.nextInt(3);
          player.contractRole = player.overall >= club.overall ? 'important' : 'rotation';
          player.releaseClause = player.value * (2.0 + club.reputation / 100.0);
        } else {
          _releasePlayer(player);
          continue;
        }
      }

      // Gwiazdy i zawodnicy w dobrej formie dostają podwyżkę.
      final shouldRaise = player.overall >= club.minimumSigningOverall &&
          (player.form >= 78 || player.overall >= club.overall + 3);
      if (shouldRaise && _random.nextDouble() < 0.35) {
        player.weeklyWage *= 1.04 + _random.nextDouble() * 0.10;
      }

      // Zapisujemy również warunki pozapłacowe kontraktu, aby przyszłe
      // negocjacje mogły porównywać pełny pakiet, a nie tylko pensję.
      player.wageExpectation = max(1, (player.weeklyWage * (1.0 + player.agentInfluence / 1000)).round());
      if (player.overall >= club.minimumSigningOverall) {
        player.appearanceBonus = max(player.appearanceBonus, (player.weeklyWage * .15).round());
        player.goalBonus = max(player.goalBonus, (player.weeklyWage * .35).round());
        player.assistBonus = max(player.assistBonus, (player.weeklyWage * .22).round());
        player.trophyBonus = max(player.trophyBonus, (player.weeklyWage * 10).round());
      }

      // Gdy do końca został jeden rok, klub może odnowić umowę wcześniej.
      // Dzięki temu kolejny sezon nie zaczyna się od przypadkowych kontraktów
      // z zerowym stażem.
      if (player.contractYearsRemaining == 1 && wantsToKeep(club, player)) {
        final renewalChance = player.overall >= club.minimumSigningOverall
            ? 0.82
            : player.overall >= club.minimumSigningOverall - 5 ? 0.58 : 0.22;
        if (_random.nextDouble() < renewalChance) {
          player.contractYearsRemaining = player.age >= 30 ? 1 : 2 + _random.nextInt(3);
          player.contractRole = player.overall >= club.overall ? 'important' : 'rotation';
          player.releaseClause = player.value * (2.0 + club.reputation / 100.0);
        }
      }

      // Klub w kryzysie finansowym ogranicza kosztowne kontrakty.
      if (club.financialHealth < 25 && player.overall < club.minimumSigningOverall - 5) {
        player.weeklyWage *= 0.98;
      }
    }
  }

  void _releasePlayer(Player player) {
    player.hasProfessionalContract = false;
    player.clubId = null;
    player.loanFromClubId = null;
    player.loanUntilDay = 0;
    player.transferRequest = false;
    player.squadStatus = 'freeAgent';
    player.managerRelationship = 50;
  }

  bool wantsToKeep(Club club, Player player) {
    if (club.financialHealth < 20 && player.weeklyWage > club.budget / 1000) return false;
    if (player.overall < club.minimumSigningOverall - 12 && player.age >= 29) return false;
    return true;
  }
}
