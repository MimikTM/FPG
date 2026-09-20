import 'dart:math';

import '../models/match_2d.dart';
import '../models/player.dart';
import 'gameplay_result_authority.dart';
import 'match_2d_engine.dart';
import '../models/match_passing_network.dart';
import '../models/attacking_run.dart';
import '../models/match_momentum.dart';

/// Headless full-match runner for Phase 6 validation.
///
/// This is deliberately a thin orchestration layer: Match2DEngine remains the
/// single gameplay authority. The runner only advances the authoritative
/// clock, captures events and exposes a compact validation snapshot.
class FullMatchSimulation {
  final Random random;
  final int maxTicks;

  FullMatchSimulation({Random? random, this.maxTicks = 12000})
      : random = random ?? Random();

  FullMatchSimulationResult run({
    required List<Player> home,
    required List<Player> away,
    String homeManagerStyle = 'balanced',
    String awayManagerStyle = 'balanced',
    bool gameplayResultAuthority = true,
    int? targetHomeGoals,
    int? targetAwayGoals,
  }) {
    final engine = Match2DEngine(random: random);
    final state = engine.create(
      home: home,
      away: away,
      targetHomeGoals: targetHomeGoals,
      targetAwayGoals: targetAwayGoals,
      homeManagerStyle: homeManagerStyle,
      awayManagerStyle: awayManagerStyle,
      gameplayResultAuthority: gameplayResultAuthority,
    );

    var ticks = 0;
    while (!state.finished && ticks < maxTicks) {
      engine.tick();
      ticks++;
    }

    final completed = state.finished;
    final snapshot = engine.gameplayResultSnapshot;
    final events = engine.events;
    final goals = events.where((e) => e.type == Match2DEventType.goal).length;
    final shots = events.where((e) => e.type == Match2DEventType.shot).length;
    final saves = events.where((e) => e.type == Match2DEventType.save).length;
    final cards = events.where((e) => e.type == Match2DEventType.card).length;
    final fouls = events.where((e) => e.type == Match2DEventType.foul).length;
    final corners = events.where((e) => e.type == Match2DEventType.corner).length;
    final substitutions = events.where((e) => e.type == Match2DEventType.substitution).length;
    final homeShots = events.where((e) => e.type == Match2DEventType.shot &&
        state.players.any((p) => p.id == e.playerId && p.team == Match2DTeam.home)).length;
    final awayShots = shots - homeShots;

    return FullMatchSimulationResult(
      completed: completed,
      ticks: ticks,
      minute: state.minute,
      homeGoals: state.homeGoals,
      awayGoals: state.awayGoals,
      goals: goals,
      shots: shots,
      homeShots: homeShots,
      awayShots: awayShots,
      saves: saves,
      cards: cards,
      fouls: fouls,
      corners: corners,
      substitutions: substitutions,
      eventCount: events.length,
      expectedGoals: engine.expectedGoals,
      expectedGoalsHome: engine.expectedGoalsHome,
      expectedGoalsAway: engine.expectedGoalsAway,
      passingNetworkHome: engine.passingNetworkHome,
      passingNetworkAway: engine.passingNetworkAway,
      attackingRuns: engine.attackingRunSnapshot,
      momentum: engine.momentumSnapshot,
      snapshot: snapshot,
      deterministicSignature: _signature(state, events),
    );
  }

  String _signature(Match2DState state, List<Match2DEvent> events) {
    final buffer = StringBuffer()
      ..write(state.homeGoals)
      ..write(':')
      ..write(state.awayGoals)
      ..write('|')
      ..write(state.minute)
      ..write('|');
    for (final event in events) {
      buffer
        ..write(event.minute)
        ..write(':')
        ..write(event.type.name)
        ..write(':')
        ..write(event.playerId)
        ..write(';');
    }
    return buffer.toString();
  }
}

class FullMatchSimulationResult {
  final bool completed;
  final int ticks;
  final int minute;
  final int homeGoals;
  final int awayGoals;
  final int goals;
  final int shots;
  final int homeShots;
  final int awayShots;
  final int saves;
  final int cards;
  final int fouls;
  final int corners;
  final int substitutions;
  final int eventCount;
  final double expectedGoals;
  final double expectedGoalsHome;
  final double expectedGoalsAway;
  final TeamPassingNetworkSnapshot passingNetworkHome;
  final TeamPassingNetworkSnapshot passingNetworkAway;
  final AttackingRunSnapshot attackingRuns;
  final MatchMomentumSnapshot momentum;
  final GameplayResultSnapshot snapshot;
  final String deterministicSignature;

  const FullMatchSimulationResult({
    required this.completed,
    required this.ticks,
    required this.minute,
    required this.homeGoals,
    required this.awayGoals,
    required this.goals,
    required this.shots,
    required this.homeShots,
    required this.awayShots,
    required this.saves,
    required this.cards,
    required this.fouls,
    required this.corners,
    required this.substitutions,
    required this.eventCount,
    required this.expectedGoals,
    required this.expectedGoalsHome,
    required this.expectedGoalsAway,
    required this.passingNetworkHome,
    required this.passingNetworkAway,
    required this.attackingRuns,
    required this.momentum,
    required this.snapshot,
    required this.deterministicSignature,
  });

  bool get scoreLedgerConsistent => snapshot.consistent;

  int get totalGoals => homeGoals + awayGoals;
}
