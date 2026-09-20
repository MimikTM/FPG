import '../models/player_role.dart';
import 'dart:math';
import '../models/player.dart';
import '../models/match_2d.dart';
import '../models/match_result.dart';
import '../models/team_play_style.dart';
import '../models/match_transition.dart';
import 'match_situation_engine.dart';
import 'match_duel_engine.dart';
import '../models/match_player_decision.dart';
import 'set_piece_engine.dart';
import 'match_contact_engine.dart';
import 'player_movement_engine.dart';
import 'ball_physics_engine.dart';
import 'referee_engine.dart';
import 'chance_creation_engine.dart';
import 'goalkeeper_engine.dart';
import 'gameplay_result_authority.dart';
import '../models/match_passing_network.dart';
import '../models/attacking_run.dart';
import 'attacking_run_engine.dart';
import '../models/match_momentum.dart';
import 'match_momentum_engine.dart';

class Match2DStep {
  final Match2DEvent? event;
  final bool keyMoment;
  const Match2DStep({this.event, this.keyMoment = false});
}

/// Real-time 2D match presentation.
///
/// The league engine remains the source of the official result. This engine
/// is responsible for the minute-by-minute presentation and for pausing on
/// player-controlled key actions. A key action is NOT resolved before the
/// mini-game: applyMiniGameOutcome() resolves it afterwards.
class Match2DEngine {
  final Random random;
  late final MatchSituationEngine _situations;
  late final MatchDuelEngine _duels;
  final MatchPlayerDecisionEngine _playerDecisions = const MatchPlayerDecisionEngine();
  late final SetPieceEngine _setPieces;
  late final MatchContactEngine _contacts;
  late final RefereeEngine _referee;
  final PlayerMovementEngine _movement = const PlayerMovementEngine();
  final BallPhysicsEngine _ballPhysics = const BallPhysicsEngine();
  late final ChanceCreationEngine _chances;
  final GoalkeeperEngine _goalkeepers = const GoalkeeperEngine();
  double? _flightStartX;
  double? _flightStartY;
  BallLaunch? _activeBallLaunch;
  double _controlledInputX = 0;
  double _controlledInputY = 0;
  Match2DState? state;
  String? controlledPlayerId;
  String homeManagerStyle = 'balanced';
  String awayManagerStyle = 'balanced';
  /// When enabled, the 2D gameplay result is emergent. Legacy fixtures can
  /// keep passing target goals while shadow mode compares both authorities.
  bool gameplayResultAuthority = false;
  late final GameplayResultAuthority _resultAuthority;

  /// Maximum number of player-controlled decisive moments in one match.
  /// This keeps the New Star Soccer-like rhythm: a few important actions,
  /// not a mini-game every time the player touches the ball.
  final int maxPlayerKeyMoments;
  int _playerKeyMoments = 0;
  int _lastPlayerKeyMinute = -100;
  final List<int> _guaranteedMomentMinutes = <int>[14, 32, 58, 76];
  int _guaranteedMomentIndex = 0;
  int _addedTime = 0;
  bool _addedTimeCalculated = false;
  double _frameAccumulator = 0;
  double _looseBallTime = 0;
  bool _halftimeEventShown = false;
  int _homeSubstitutions = 0;
  int _awaySubstitutions = 0;
  double _expectedGoals = 0;
  double _expectedGoalsHome = 0;
  double _expectedGoalsAway = 0;
  final PassingNetworkTracker _passingNetwork = PassingNetworkTracker();
  final AttackingRunEngine _attackingRuns = const AttackingRunEngine();
  final MatchMomentumEngine _momentum = const MatchMomentumEngine();
  int _homeRuns = 0;
  int _awayRuns = 0;
  int _homeDangerousRuns = 0;
  int _awayDangerousRuns = 0;
  int _homeOverlaps = 0;
  int _awayOverlaps = 0;
  int _homeChannelRuns = 0;
  int _awayChannelRuns = 0;
  String? _possessionSequenceTeam;

  AttackingRunSnapshot get attackingRunSnapshot => AttackingRunSnapshot(
    homeRuns: _homeRuns, awayRuns: _awayRuns,
    homeDangerousRuns: _homeDangerousRuns, awayDangerousRuns: _awayDangerousRuns,
    homeOverlaps: _homeOverlaps, awayOverlaps: _awayOverlaps,
    homeChannelRuns: _homeChannelRuns, awayChannelRuns: _awayChannelRuns,
  );

  final List<Match2DEvent> _events = [];
  final List<int> _homeGoalMinutes = [];
  final List<int> _awayGoalMinutes = [];
  final Set<int> _resolvedScheduledGoalsHome = {};
  final Set<int> _resolvedScheduledGoalsAway = {};
  final Set<String> _startingPlayerIds = <String>{};

  // The official simulation is only a pre-match estimate. Player actions
  // can now move the final result by a small, realistic amount.
  int _interactiveHomeDelta = 0;
  int _interactiveAwayDelta = 0;
  int _missedPlayerGoals = 0;
  MatchSituation? _activeSituation;
  int _activeBeat = 0;
  String? _activeSituationId;
  String? _previousBallOwnerId;

  Match2DEngine({Random? random, this.maxPlayerKeyMoments = 5})
      : random = random ?? Random() {
    _situations = MatchSituationEngine(random: random);
    _duels = MatchDuelEngine(random: random);
    _setPieces = SetPieceEngine(random: random);
    _contacts = MatchContactEngine(random: random);
    _referee = RefereeEngine(random: random);
    _chances = ChanceCreationEngine(random: random);
    _resultAuthority = GameplayResultAuthority();
  }

  Match2DState create({
    required List<Player> home,
    required List<Player> away,
    int? targetHomeGoals,
    int? targetAwayGoals,
    String? controlledPlayerId,
    String homeManagerStyle = 'balanced',
    String awayManagerStyle = 'balanced',
    bool gameplayResultAuthority = false,
  }) {
    this.controlledPlayerId = controlledPlayerId;
    this.homeManagerStyle = homeManagerStyle;
    this.awayManagerStyle = awayManagerStyle;
    this.gameplayResultAuthority = gameplayResultAuthority;
    _resultAuthority.reset();
    _playerKeyMoments = 0;
    _lastPlayerKeyMinute = -100;
    _guaranteedMomentIndex = 0;
    _interactiveHomeDelta = 0;
    _interactiveAwayDelta = 0;
    _missedPlayerGoals = 0;
    _addedTime = 0;
    _addedTimeCalculated = false;
    _frameAccumulator = 0;
    _looseBallTime = 0;
    _halftimeEventShown = false;
    _homeSubstitutions = 0;
    _awaySubstitutions = 0;
    _expectedGoals = 0;
    _expectedGoalsHome = 0;
    _expectedGoalsAway = 0;
    _passingNetwork.reset();
    _possessionSequenceTeam = null;
    _homeRuns = _awayRuns = _homeDangerousRuns = _awayDangerousRuns = 0;
    _homeOverlaps = _awayOverlaps = _homeChannelRuns = _awayChannelRuns = 0;
    _activeSituation = null;
    _activeBeat = 0;
    _activeSituationId = null;
    _previousBallOwnerId = null;
    _controlledInputX = 0;
    _controlledInputY = 0;
    _flightStartX = null;
    _flightStartY = null;
    _activeBallLaunch = null;

    final homeXI = _pickXI(home, forcePlayerId: controlledPlayerId);
    final awayXI = _pickXI(away, forcePlayerId: controlledPlayerId);
    final homeBench = _pickBench(home, homeXI);
    final awayBench = _pickBench(away, awayXI);
    final players = <Match2DPlayer>[
      for (var i = 0; i < homeXI.length; i++)
        make2DPlayer(homeXI[i], Match2DTeam.home, i, managerStyle: homeManagerStyle),
      for (var i = 0; i < awayXI.length; i++)
        make2DPlayer(awayXI[i], Match2DTeam.away, i, managerStyle: awayManagerStyle),
    ];
    final benchPlayers = <Match2DPlayer>[
      for (var i = 0; i < homeBench.length; i++)
        make2DPlayer(homeBench[i], Match2DTeam.home, i + 11, managerStyle: homeManagerStyle),
      for (var i = 0; i < awayBench.length; i++)
        make2DPlayer(awayBench[i], Match2DTeam.away, i + 11, managerStyle: awayManagerStyle),
    ];

    Match2DPlayer owner;
    final controlled = controlledPlayerId == null
        ? null
        : players.where((p) => p.id == controlledPlayerId).firstOrNull;
    owner = controlled ??
        players.firstWhere(
          (p) => p.position == PlayerPosition.midfielder &&
              p.team == Match2DTeam.home,
          orElse: () => players.first,
        );

    owner.hasBall = true;
    state = Match2DState(
      players: players,
      benchPlayers: benchPlayers,
      ballX: owner.x,
      ballY: owner.y,
      ballOwnerId: owner.id,
      ballTargetOwnerId: null,
      ballTravelProgress: 1.0,
      ballVelocityX: 0,
      ballVelocityY: 0,
      ballHeight: 0,
      ballSpin: 0,
      ballBounce: 0,
      targetHomeGoals: gameplayResultAuthority ? null : targetHomeGoals,
      targetAwayGoals: gameplayResultAuthority ? null : targetAwayGoals,
    );

    _events.clear();
    _homeGoalMinutes
      ..clear()
      ..addAll(gameplayResultAuthority ? const <int>[] : _planGoalMinutes(targetHomeGoals ?? 0));
    _awayGoalMinutes
      ..clear()
      ..addAll(gameplayResultAuthority ? const <int>[] : _planGoalMinutes(targetAwayGoals ?? 0));
    _resolvedScheduledGoalsHome.clear();
    _resolvedScheduledGoalsAway.clear();
    _startingPlayerIds
      ..clear()
      ..addAll(players.map((p) => p.id));

    return state!;
  }

  List<int> _planGoalMinutes(int count) {
    final minutes = <int>{};
    while (minutes.length < count) {
      minutes.add(5 + random.nextInt(86));
    }
    return minutes.toList()..sort();
  }

  /// Sets normalized movement intent for the currently controlled player.
  /// The intent is consumed by the authoritative match tick, so rendering
  /// never becomes a second movement source of truth.
  void setControlledMovement(double x, double y) {
    final length = sqrt(x * x + y * y);
    if (length <= .001) {
      _controlledInputX = 0;
      _controlledInputY = 0;
      return;
    }
    _controlledInputX = (x / length).clamp(-1.0, 1.0).toDouble();
    _controlledInputY = (y / length).clamp(-1.0, 1.0).toDouble();
  }

  Match2DStep tick() {
    final s = state;
    if (s == null || s.finished) return const Match2DStep();

    // The match is rendered frame-by-frame. Positions and the ball move on
    // every frame, while the official match clock advances roughly once per
    // 0.72 seconds. This removes the old teleport/jump effect.
    _frameAccumulator += 0.12;
    _movePlayers(s);
    if (_frameAccumulator < .72) return const Match2DStep();
    _frameAccumulator = 0;

    // The match always reaches 90'. Only then do we calculate stoppage time.
    // The added time is influenced by realistic disruptions: goals,
    // substitutions, injuries and cards. It is clamped to 1–15 minutes.
    if (s.minute == 90 && !_addedTimeCalculated) {
      _addedTime = _calculateStoppageTime();
      s.stoppageTime = _addedTime;
      _addedTimeCalculated = true;
      final event = Match2DEvent(
        type: Match2DEventType.stoppageTime,
        playerId: s.ballOwnerId ?? s.players.first.id,
        description: 'Sędzia dolicza +$_addedTime min.',
        minute: 90,
        x: s.ballX,
        y: s.ballY,
      );
      _events.add(event);
      return Match2DStep(event: event);
    }

    if (s.minute == 45 && !_halftimeEventShown) {
      _halftimeEventShown = true;
      _switchEnds(s);
      final event = Match2DEvent(type: Match2DEventType.halftime, playerId: s.ballOwnerId ?? s.players.first.id, description: 'PRZERWA — koniec pierwszej połowy', minute: 45, x: s.ballX, y: s.ballY);
      _events.add(event);
      return Match2DStep(event: event);
    }

    // From 90' onward, minute is stored as total elapsed minutes (91..105),
    // while the UI formats it as 90+1 .. 90+15.
    s.minute++;
    _recordPossessionSecond(s);
    for (final p in s.players) {
      if (p.active) {
        p.minutesPlayed = min(90, p.minutesPlayed + 1);
        _applyMatchFatigue(p, s);
      }
    }

    final incident = _maybeMatchIncident(s);
    if (incident != null) return Match2DStep(event: incident);

    // The 2D view must narrate the same official result. If the pre-match
    // simulation scheduled a goal for this minute, materialise it here instead
    // of dumping missing goals into the final minute. Interactive actions may
    // still change the result by the existing small +/-1 rule.
    final scheduledGoal = gameplayResultAuthority ? null : _materializeScheduledGoal(s);
    if (scheduledGoal != null) {
      return Match2DStep(event: scheduledGoal, keyMoment: false);
    }

    final guaranteed = _maybeGuaranteedPlayerMoment(s);
    if (guaranteed != null) {
      return Match2DStep(event: guaranteed, keyMoment: true);
    }

    final situationEvent = _advanceSituation(s);
    if (situationEvent != null) {
      if (_isMatchOver(s)) {
        final forced = gameplayResultAuthority ? null : _forceSyncFinalScore(s);
        s.finished = true;
        final endEvent = Match2DEvent(
          type: Match2DEventType.fulltime,
          playerId: s.ballOwnerId ?? s.players.first.id,
          description: 'KONIEC MECZU',
          minute: s.minute,
          x: s.ballX,
          y: s.ballY,
        );
        return Match2DStep(
          event: forced ?? endEvent,
          keyMoment: forced?.isKeyMoment ?? false,
        );
      }
      return Match2DStep(
        event: situationEvent,
        keyMoment: situationEvent.isKeyMoment,
      );
    }

    final event = _maybeAction(s);

    if (_isMatchOver(s)) {
      final forced = gameplayResultAuthority ? null : _forceSyncFinalScore(s);
      s.finished = true;
      final endEvent = Match2DEvent(
        type: Match2DEventType.fulltime,
        playerId: s.ballOwnerId ?? s.players.first.id,
        description: 'KONIEC MECZU',
        minute: s.minute,
        x: s.ballX,
        y: s.ballY,
      );
      return Match2DStep(
        event: forced ?? endEvent,
        keyMoment: forced?.isKeyMoment ?? false,
      );
    }

    return Match2DStep(
      event: event,
      keyMoment: event?.isKeyMoment ?? false,
    );
  }

  bool _isMatchOver(Match2DState s) =>
      _addedTimeCalculated && s.minute >= 90 + _addedTime;

  int _calculateStoppageTime() {
    var seconds = 45 + random.nextInt(76); // baseline: 0:45–2:00
    for (final event in _events) {
      switch (event.type) {
        case Match2DEventType.goal:
          seconds += 45 + random.nextInt(31); // 0:45–1:15
          break;
        case Match2DEventType.injury:
          seconds += 60 + random.nextInt(121); // 1:00–3:00
          break;
        case Match2DEventType.substitution:
          seconds += 25 + random.nextInt(26); // 0:25–0:50
          break;
        case Match2DEventType.card:
          seconds += 15 + random.nextInt(21); // 0:15–0:35
          break;
        default:
          break;
      }
    }
    return (seconds / 60).ceil().clamp(1, 15);
  }

  /// UI-friendly clock text: 1'..90', then 90+1'..90+15'.
  String formatMatchMinute([int? minute]) {
    final m = minute ?? state?.minute ?? 0;
    if (m <= 90) return "$m'";
    final added = m - 90;
    return '90+$added\'';
  }

  List<Match2DEvent> get events => List.unmodifiable(_events);

  List<Player> _pickXI(List<Player> source, {String? forcePlayerId}) {
    final sorted = [...source]..sort((a, b) => b.overall.compareTo(a.overall));
    final result = <Player>[];

    void add(PlayerPosition position, int count) {
      for (final player in sorted.where((p) => p.position == position)) {
        if (result.length >= 11 || count == 0) break;
        if (!result.contains(player)) {
          result.add(player);
          count--;
        }
      }
    }

    add(PlayerPosition.goalkeeper, 1);
    add(PlayerPosition.defender, 4);
    add(PlayerPosition.midfielder, 3);
    add(PlayerPosition.winger, 2);
    add(PlayerPosition.striker, 1);

    if (forcePlayerId != null) {
      final forced = sorted.where((p) => p.id == forcePlayerId).firstOrNull;
      if (forced != null && !result.contains(forced)) {
        if (result.length >= 11) {
          // Replace the lowest-rated outfield player. A player who is in the
          // actual match transaction must be visible on the 2D pitch.
          final replaceable = result
              .where((p) => p.position != PlayerPosition.goalkeeper)
              .toList()
            ..sort((a, b) => a.overall.compareTo(b.overall));
          if (replaceable.isNotEmpty) result.remove(replaceable.first);
        }
        result.add(forced);
      }
    }

    for (final p in sorted) {
      if (result.length >= 11) break;
      if (!result.contains(p)) result.add(p);
    }
    return result.take(11).toList();
  }

  List<Player> _pickBench(List<Player> source, List<Player> starters) {
    final used = starters.map((p) => p.id).toSet();
    final sorted = [...source]..sort((a, b) => b.overall.compareTo(a.overall));
    return sorted.where((p) => !used.contains(p.id) && !p.injured).take(7).toList();
  }

  void _moveBallToTeamRestart(Match2DState s, Match2DTeam team) {
    final candidates = s.players.where((p) => p.active && p.team == team).toList();
    if (candidates.isEmpty) return;
    final player = candidates[random.nextInt(candidates.length)];
    for (final p in s.players) p.hasBall = false;
    player.hasBall = true;
    s.ballOwnerId = player.id;
    s.ballTargetOwnerId = null;
    s.ballTravelProgress = 1.0;
    s.ballX = player.x;
    s.ballY = player.y;
    s.ballVelocityX = 0;
    s.ballVelocityY = 0;
    s.ballHeight = 0;
    s.ballSpin = 0;
    s.ballBounce = 0;
    _looseBallTime = 0;
  }

  void _switchEnds(Match2DState s) {
    for (final p in [...s.players, ...s.benchPlayers]) {
      p.x = 100 - p.x;
      p.homeX = 100 - p.homeX;
    }
    s.ballX = 100 - s.ballX;
  }

  Match2DEvent? _maybeMatchIncident(Match2DState s) {
    if (s.minute <= 0 || s.minute > 90) return null;

    // Tactical substitutions: the match now prefers changes that have a
    // football reason (fatigue, booking risk, chasing/protecting the score)
    // instead of purely random minute-based swaps. The legacy limit of three
    // changes per side is intentionally preserved.
    if (s.minute >= 55 && s.minute <= 88 && [58, 67, 76, 84].contains(s.minute)) {
      final homeDue = _homeSubstitutions < 3 && _shouldMakeTacticalSubstitution(s, Match2DTeam.home);
      final awayDue = _awaySubstitutions < 3 && _shouldMakeTacticalSubstitution(s, Match2DTeam.away);
      if (homeDue || awayDue) {
        Match2DTeam team;
        if (homeDue && awayDue) {
          final homePriority = _substitutionPriority(s, Match2DTeam.home);
          final awayPriority = _substitutionPriority(s, Match2DTeam.away);
          team = homePriority >= awayPriority ? Match2DTeam.home : Match2DTeam.away;
        } else {
          team = homeDue ? Match2DTeam.home : Match2DTeam.away;
        }
        final sub = _makeSubstitution(s, team);
        if (sub != null) return sub;
      }
    }

    // A football match has frequent restarts: throw-ins and corners.
    if (random.nextDouble() < .26) {
      final team = random.nextBool() ? Match2DTeam.home : Match2DTeam.away;
      final corner = random.nextDouble() < .28;
      final candidates = s.players.where((p) => p.active && p.team == team).toList();
      if (candidates.isNotEmpty) {
        final player = candidates[random.nextInt(candidates.length)];
        if (corner) {
          player.x = team == Match2DTeam.home ? 96 : 4;
          player.y = random.nextBool() ? 6 : 94;
          final attackers = s.players.where((p) => p.active && p.team == team && p.position != PlayerPosition.goalkeeper).toList();
          final defenders = s.players.where((p) => p.active && p.team != team && p.position != PlayerPosition.goalkeeper).toList();
          final plan = _setPieces.corner(taker: player, attackers: attackers, defenders: defenders, attackingHome: team == Match2DTeam.home);
          for (final p in s.players) p.hasBall = false;
          player.hasBall = true;
          s.ballOwnerId = player.id;
          s.ballTargetOwnerId = plan.target?.id;
          s.ballTravelProgress = plan.target == null ? 1.0 : 0.0;
          s.ballX = player.x;
          s.ballY = player.y;
          final event = Match2DEvent(type: Match2DEventType.corner, playerId: player.id, secondaryPlayerId: plan.target?.id, description: 'Rzut rożny — ${_setPieceDescription(plan.outcome)}', minute: s.minute, x: s.ballX, y: s.ballY);
          _recordEventStats(s, event: event.type, team: team, keyMoment: false);
          _events.add(event);
          return event;
        }
        for (final p in s.players) p.hasBall = false;
        player.hasBall = true;
        s.ballOwnerId = player.id;
        s.ballTargetOwnerId = null;
        s.ballTravelProgress = 1.0;
        s.ballVelocityX = 0;
        s.ballVelocityY = 0;
        s.ballHeight = 0;
        s.ballX = player.x;
        s.ballY = player.y;
        final event = Match2DEvent(type: Match2DEventType.throwIn, playerId: player.id, description: 'Aut — ${player.name} wznawia grę', minute: s.minute, x: s.ballX, y: s.ballY);
        _recordEventStats(s, event: event.type, team: team, keyMoment: false);
        _events.add(event);
        return event;
      }
    }

    // Fouls create cards, injuries and changes of possession.
    if (random.nextDouble() < .18) {
      final victim = s.players.firstWhere((p) => p.id == s.ballOwnerId, orElse: () => s.players.first);
      final tacklers = s.players.where((p) => p.active && p.team != victim.team && p.position != PlayerPosition.goalkeeper).toList();
      if (tacklers.isNotEmpty) {
        final fouler = tacklers[random.nextInt(tacklers.length)];
        final restartCandidates = s.players.where((p) => p.active && p.team == victim.team && p.position != PlayerPosition.goalkeeper).toList();
        final taker = restartCandidates.isEmpty ? victim : restartCandidates.reduce((a, b) => a.passing >= b.passing ? a : b);
        final defenders = s.players.where((p) => p.active && p.team != victim.team && p.position != PlayerPosition.goalkeeper).toList();
        final distanceToGoal = victim.team == Match2DTeam.home ? (100 - fouler.x).abs() : fouler.x.abs();
        final inPenaltyArea = distanceToGoal < 18 && fouler.y > 18 && fouler.y < 82;
        final referee = _referee.resolveChallenge(
          defender: fouler,
          attacker: victim,
          distance: _distanceXY(fouler.x, fouler.y, victim.x, victim.y),
          speed: sqrt(fouler.velocityX * fouler.velocityX + fouler.velocityY * fouler.velocityY),
          inPenaltyArea: inPenaltyArea,
          minute: s.minute,
        );
        if (!referee.isFoul) return null;
        final plan = referee.restart == RefereeRestart.penalty
            ? _setPieces.penalty(taker: taker, defenders: defenders, attackingHome: victim.team == Match2DTeam.home)
            : _setPieces.freeKick(taker: taker, attackers: restartCandidates, defenders: defenders, attackingHome: victim.team == Match2DTeam.home, distanceToGoal: distanceToGoal);
        if (!referee.advantage) _moveBallToTeamRestart(s, victim.team);
        if (fouler.team == Match2DTeam.home) s.stats.homeFouls++; else s.stats.awayFouls++;
        if (referee.card == RefereeCard.red) {
          fouler.redCard = true;
          fouler.active = false;
          fouler.hasBall = false;
          s.stats.homeRedCards += fouler.team == Match2DTeam.home ? 1 : 0;
          s.stats.awayRedCards += fouler.team == Match2DTeam.away ? 1 : 0;
        } else if (referee.card == RefereeCard.yellow) {
          fouler.yellowCard = true;
          if (fouler.team == Match2DTeam.home) s.stats.homeYellowCards++; else s.stats.awayYellowCards++;
        }
        final eventType = referee.card != RefereeCard.none ? Match2DEventType.card : (referee.restart == RefereeRestart.penalty ? Match2DEventType.penalty : Match2DEventType.freeKick);
        final desc = referee.card == RefereeCard.red ? '${fouler.name} — CZERWONA KARTKA' : referee.card == RefereeCard.yellow ? '${fouler.name} otrzymuje żółtą kartkę' : referee.advantage ? '${fouler.name} fauluje — GRA NA KORZYŚĆ' : '${fouler.name} fauluje — ${eventType == Match2DEventType.penalty ? 'rzut karny' : 'rzut wolny'}';
        if (eventType == Match2DEventType.penalty) {
          final scored = _resolveShot(s, taker);
          if (scored) {
            _events.add(Match2DEvent(type: Match2DEventType.goal, playerId: taker.id, secondaryPlayerId: fouler.id, description: 'GOOOL! ${taker.name} wykorzystuje rzut karny', minute: s.minute, x: s.ballX, y: s.ballY));
          }
        }
        final event = Match2DEvent(type: eventType, playerId: taker.id, secondaryPlayerId: victim.id, description: eventType == Match2DEventType.penalty ? 'RZUT KARNY — ${taker.name}' : desc, minute: s.minute, x: fouler.x, y: fouler.y);
        _recordEventStats(s, event: eventType, team: fouler.team, keyMoment: false);
        _events.add(event);
        return event;
      }
    }

    // Injuries are uncommon but persistent: the injured player leaves and is replaced.
    if (random.nextDouble() < .018) {
      final candidates = s.players.where((p) => p.active && p.position != PlayerPosition.goalkeeper).toList();
      if (candidates.isNotEmpty) {
        final injured = candidates[random.nextInt(candidates.length)];
        injured.injured = true;
        injured.active = false;
        injured.hasBall = false;
        final replacement = _makeSubstitution(s, injured.team, injuredPlayerId: injured.id);
        final event = Match2DEvent(type: Match2DEventType.injury, playerId: injured.id, secondaryPlayerId: replacement?.playerId, description: '${injured.name} doznaje urazu i musi opuścić boisko', minute: s.minute, x: injured.x, y: injured.y);
        _events.add(event);
        return event;
      }
    }
    return null;
  }

  String _setPieceDescription(SetPieceOutcome outcome) => switch (outcome) {
    SetPieceOutcome.cleanHeader => 'czyste dojście do główki',
    SetPieceOutcome.headerChance => 'piłka na głowę',
    SetPieceOutcome.secondBall => 'walka o drugą piłkę',
    SetPieceOutcome.cleared => 'obrona wybija dośrodkowanie',
    SetPieceOutcome.directShot => 'bezpośredni strzał',
    SetPieceOutcome.crossChance => 'dośrodkowanie na partnerów',
    SetPieceOutcome.recycled => 'spokojne rozegranie',
  };

  void _applyMatchFatigue(Match2DPlayer p, Match2DState s) {
    // Fatigue is deliberately gradual and runtime-only. High-intensity roles
    // and teams pressing/chasing the game lose a little more stamina.
    final style = TeamPlayStyleProfile.fromManagerStyle(
      p.team == Match2DTeam.home ? homeManagerStyle : awayManagerStyle,
    ).style;
    final highIntensity = style == TeamPlayStyle.highPress || style == TeamPlayStyle.direct;
    final goalDiff = p.team == Match2DTeam.home
        ? s.homeGoals - s.awayGoals
        : s.awayGoals - s.homeGoals;
    final chasing = goalDiff < 0 && s.minute >= 70;
    p.staminaAccumulator += .18 + (highIntensity ? .07 : 0) + (chasing ? .09 : 0);
    if (p.staminaAccumulator >= 1) {
      final drain = p.staminaAccumulator.floor();
      p.stamina = max(0, p.stamina - drain);
      p.staminaAccumulator -= drain;
    }
  }

  double _substitutionPriority(Match2DState s, Match2DTeam team) {
    final active = s.players.where((p) => p.active && p.team == team && p.position != PlayerPosition.goalkeeper).toList();
    if (active.isEmpty) return 0;
    final avgStamina = active.fold<double>(0, (sum, p) => sum + p.stamina) / active.length;
    final lowest = active.map((p) => p.stamina).reduce(min);
    final ownGoals = team == Match2DTeam.home ? s.homeGoals : s.awayGoals;
    final oppGoals = team == Match2DTeam.home ? s.awayGoals : s.homeGoals;
    final chasing = ownGoals < oppGoals;
    final protecting = ownGoals > oppGoals;
    return (100 - avgStamina) * .55 + (100 - lowest) * .25 +
        (chasing ? 14 : 0) + (protecting ? 5 : 0);
  }

  bool _shouldMakeTacticalSubstitution(Match2DState s, Match2DTeam team) {
    final bench = s.benchPlayers.where((p) => p.team == team && p.active && !p.injured).toList();
    if (bench.isEmpty) return false;
    final active = s.players.where((p) => p.active && p.team == team && p.position != PlayerPosition.goalkeeper).toList();
    if (active.isEmpty) return false;
    final priority = _substitutionPriority(s, team);
    final ownGoals = team == Match2DTeam.home ? s.homeGoals : s.awayGoals;
    final oppGoals = team == Match2DTeam.home ? s.awayGoals : s.homeGoals;
    final lateChase = ownGoals < oppGoals && s.minute >= 70;
    final fatigueTrigger = active.any((p) => p.stamina <= 68);
    return fatigueTrigger || priority >= 24 || lateChase;
  }

  Match2DEvent? _makeSubstitution(Match2DState s, Match2DTeam team, {String? injuredPlayerId}) {
    final outgoing = s.players.where((p) => (p.active || p.id == injuredPlayerId) && p.team == team && p.position != PlayerPosition.goalkeeper && p.id != controlledPlayerId).toList();
    if (outgoing.isEmpty) return null;
    final candidates = s.benchPlayers.where((p) => p.team == team && p.active && !p.injured).toList();
    if (candidates.isEmpty) return null;
    final off = injuredPlayerId == null ? outgoing[random.nextInt(outgoing.length)] : outgoing.firstWhere((p) => p.id == injuredPlayerId, orElse: () => outgoing.first);
    final on = candidates[random.nextInt(candidates.length)];
    off.active = false;
    off.hasBall = false;
    on.active = true;
    s.players.add(on);
    s.benchPlayers.remove(on);
    if (team == Match2DTeam.home) _homeSubstitutions++; else _awaySubstitutions++;
    _moveBallToTeamRestart(s, team);
    return Match2DEvent(type: Match2DEventType.substitution, playerId: on.id, secondaryPlayerId: off.id, description: 'Zmiana: ${on.name} za ${off.name}', minute: s.minute, x: on.x, y: on.y);
  }

  void _movePlayers(Match2DState s) {
    // A successful tackle now creates a short loose-ball phase instead of
    // teleporting possession directly to a teammate. The ball is still
    // authoritative here; the renderer only presents the resulting motion.
    if (_looseBallTime > 0) {
      _looseBallTime = max(0, _looseBallTime - .12);
      s.ballOwnerId = null;
      s.ballTargetOwnerId = null;
      s.ballTravelProgress = 1.0;
      final loose = _ballPhysics.stepLoose(
        x: s.ballX,
        y: s.ballY,
        velocityX: s.ballVelocityX,
        velocityY: s.ballVelocityY,
        spin: s.ballSpin,
        bounce: s.ballBounce,
      );
      s.ballX = loose.x;
      s.ballY = loose.y;
      s.ballVelocityX = loose.velocityX;
      s.ballVelocityY = loose.velocityY;
      s.ballSpin = loose.spin;
      s.ballBounce = loose.bounce;

      final nearest = s.players
          .where((p) => p.active)
          .fold<Match2DPlayer?>(null, (best, p) {
        if (best == null) return p;
        return _distanceXY(p.x, p.y, s.ballX, s.ballY) <
                _distanceXY(best.x, best.y, s.ballX, s.ballY)
            ? p
            : best;
      });
      if (nearest != null &&
          _distanceXY(nearest.x, nearest.y, s.ballX, s.ballY) < 5.0) {
        for (final p in s.players) p.hasBall = false;
        nearest.hasBall = true;
        s.ballOwnerId = nearest.id;
        s.ballX = nearest.x;
        s.ballY = nearest.y;
        s.ballVelocityX = 0;
        s.ballVelocityY = 0;
        s.ballHeight = 0;
        s.ballBounce = 1.0;
        _looseBallTime = 0;
      } else if (_looseBallTime <= 0) {
        // Safety recovery: never leave a match without an owner.
        if (nearest != null) {
          for (final p in s.players) p.hasBall = false;
          nearest.hasBall = true;
          s.ballOwnerId = nearest.id;
          s.ballX = nearest.x;
          s.ballY = nearest.y;
          s.ballVelocityX = 0;
          s.ballVelocityY = 0;
        }
      }
      _moveOffBallPlayers(s, nearest ?? s.players.first,
          nearest?.team ?? Match2DTeam.home);
      return;
    }

    final owner = s.players.firstWhere(
      (p) => p.id == s.ballOwnerId && p.active,
      orElse: () => s.players.firstWhere((p) => p.active, orElse: () => s.players.first),
    );

    // Passes are real ball transitions instead of instant owner swaps.
    final targetId = s.ballTargetOwnerId;
    if (targetId != null) {
      final target = s.players.firstWhere(
        (p) => p.id == targetId,
        orElse: () => owner,
      );
      if (_flightStartX == null || _flightStartY == null || _activeBallLaunch == null) {
        _flightStartX = s.ballX;
        _flightStartY = s.ballY;
        final distance = _distanceXY(_flightStartX!, _flightStartY!, target.x, target.y);
        _activeBallLaunch = _ballPhysics.launch(
          passer: owner,
          target: target,
          distance: distance,
          cross: owner.position == PlayerPosition.winger && distance > 16,
          throughBall: owner.position == PlayerPosition.midfielder && distance > 18,
        );
      }
      s.ballTravelProgress = (s.ballTravelProgress + .22).clamp(0.0, 1.0).toDouble();
      final flight = _ballPhysics.sample(
        startX: _flightStartX!,
        startY: _flightStartY!,
        endX: target.x,
        endY: target.y,
        progress: s.ballTravelProgress,
        launch: _activeBallLaunch!,
      );
      s.ballX = flight.x;
      s.ballY = flight.y;
      s.ballHeight = flight.height;
      s.ballVelocityX = flight.velocityX;
      s.ballVelocityY = flight.velocityY;
      s.ballSpin = flight.spin;
      _moveOffBallPlayers(s, owner, owner.team);

      // Authoritative player-ball collision during a travelling pass. The
      // presentation layer may animate the contact, but the actual winner of
      // the ball is decided here. This prevents the ball from passing through
      // a defender simply because the original target was selected.
      final collider = _findBallCollider(
        s,
        excludeIds: <String>{owner.id},
        preferredId: target.id,
      );
      if (collider != null) {
        final isIntendedReceiver = collider.id == target.id;
        final pressure = _nearestOpponentDistance(safePlayers: s.players, player: collider);
        final touch = _contacts.firstTouch(
          receiver: collider,
          ballSpeed: sqrt(s.ballVelocityX * s.ballVelocityX + s.ballVelocityY * s.ballVelocityY),
          pressure: pressure.isFinite ? pressure : 20,
          ballHeight: s.ballHeight,
          controlled: isIntendedReceiver && controlledPlayerId == collider.id,
        );
        final contact = _calculateContactDeflection(
          s,
          collider: collider,
          incomingX: s.ballVelocityX,
          incomingY: s.ballVelocityY,
          controlled: isIntendedReceiver,
          touchRetention: touch.retention,
        );

        owner.hasBall = false;
        for (final p in s.players) {
          if (p.id != collider.id) p.hasBall = false;
        }
        collider.hasBall = true;
        s.ballOwnerId = collider.id;
        s.ballTargetOwnerId = null;
        s.ballTravelProgress = 1.0;
        s.ballX = (collider.x + contact.offsetX).clamp(2.5, 97.5).toDouble();
        s.ballY = (collider.y + contact.offsetY).clamp(2.5, 97.5).toDouble();
        s.ballVelocityX = contact.velocityX;
        s.ballVelocityY = contact.velocityY;
        s.ballHeight = 0;
        s.ballBounce = contact.bounce;
        s.ballSpin = contact.spin;
        _flightStartX = null;
        _flightStartY = null;
        _activeBallLaunch = null;
        return;
      }

      if (s.ballTravelProgress >= 1.0) {
        owner.hasBall = false;
        target.hasBall = true;
        s.ballOwnerId = target.id;
        s.ballTargetOwnerId = null;
        s.ballTravelProgress = 1.0;
        s.ballBounce = 1.0;
        s.ballHeight = 0;
        _flightStartX = null;
        _flightStartY = null;
        _activeBallLaunch = null;
      }
      return;
    }

    final possessionTeam = owner.team;
    final previousOwner = _previousBallOwnerId == null
        ? null
        : s.players.where((p) => p.id == _previousBallOwnerId).firstOrNull;
    final homePhase = MatchTransitionProfile.phaseFor(
      state: s, team: Match2DTeam.home, owner: owner, previousOwner: previousOwner);
    final awayPhase = MatchTransitionProfile.phaseFor(
      state: s, team: Match2DTeam.away, owner: owner, previousOwner: previousOwner);
    s.homeTransition = homePhase;
    s.awayTransition = awayPhase;
    _previousBallOwnerId = owner.id;
    final direction = possessionTeam == Match2DTeam.home ? 1.0 : -1.0;
    final phase = _phaseForBall(s.ballX, possessionTeam);
    final forwardSpace = _forwardSpace(s, owner);
    final pressure = _nearestOpponentDistance(safePlayers: s.players, player: owner);
    final canCarry = forwardSpace > 9 && pressure > 7;
    if (owner.id == controlledPlayerId && (_controlledInputX.abs() + _controlledInputY.abs()) > .01) {
      final targetX = owner.x + _controlledInputX * 12.0;
      final targetY = owner.y + _controlledInputY * 12.0;
      _movement.apply(owner, targetX, targetY, urgency: 1.0);
    } else if (canCarry) {
      final targetX = (owner.x + direction * .65).clamp(4.0, 96.0).toDouble();
      _movement.apply(owner, targetX, owner.y, urgency: .22);
    } else {
      _movement.stop(owner);
    }
    final followX = (owner.x - s.ballX) * .48;
    final followY = (owner.y - s.ballY) * .48;
    s.ballVelocityX = followX / .12;
    s.ballVelocityY = followY / .12;
    s.ballX += followX;
    s.ballY += followY;
    s.ballHeight = 0;
    s.ballBounce = max(0, s.ballBounce - 0.32);
    s.ballSpin *= 0.82;

    final teammates = s.players.where((p) => p.active && p.team == possessionTeam && p.id != owner.id).toList();
    final opponents = s.players.where((p) => p.active && p.team != possessionTeam).toList();
    _updateMatchAI(
      s,
      owner: owner,
      possessionTeam: possessionTeam,
      phase: phase,
      direction: direction,
      teammates: teammates,
      opponents: opponents,
    );

    if (opponents.any((p) => _distanceXY(p.x, p.y, owner.x, owner.y) < 10) && random.nextDouble() < .16) {
      owner.stamina = max(0, owner.stamina - 1);
    }
  }

  void _updateMatchAI(
    Match2DState s, {
    required Match2DPlayer owner,
    required Match2DTeam possessionTeam,
    required Match2DPhase phase,
    required double direction,
    required List<Match2DPlayer> teammates,
    required List<Match2DPlayer> opponents,
  }) {
    // Match AI is deliberately lightweight and deterministic enough for a
    // readable 2D match: roles choose targets, then acceleration moves players
    // toward those targets. It reacts to possession, pressure and loose balls
    // without replacing the official match/result engine.
    Match2DPlayer? nearestDefender;
    var nearestDistance = double.infinity;
    for (final p in opponents) {
      final d = _distanceXY(p.x, p.y, owner.x, owner.y);
      if (d < nearestDistance) {
        nearestDistance = d;
        nearestDefender = p;
      }
    }

    // One defender presses; the others protect lanes. This prevents the whole
    // team from collapsing onto the ball carrier. Tactical mentality now also
    // reacts to the score and match phase, so teams do not keep the same
    // shape/urgency for all 90 minutes.
    final tactical = _tacticalMentality(s, possessionTeam);
    final momentum = _momentum.evaluate(
      state: s, events: _events, possessionTeam: possessionTeam == Match2DTeam.home ? 'home' : 'away');
    final momentumEdge = possessionTeam == Match2DTeam.home ? momentum.homeEdge : momentum.awayEdge;
    final ownTransition = possessionTeam == Match2DTeam.home ? s.homeTransition : s.awayTransition;
    final opponentTransition = possessionTeam == Match2DTeam.home ? s.awayTransition : s.homeTransition;
    final ownTransitionProfile = MatchTransitionProfile.fromStyle(
      possessionTeam == Match2DTeam.home ? homeManagerStyle : awayManagerStyle, ownTransition);
    final opponentTransitionProfile = MatchTransitionProfile.fromStyle(
      possessionTeam == Match2DTeam.home ? awayManagerStyle : homeManagerStyle, opponentTransition);
    for (final p in s.players) {
      if (!p.active || p.hasBall) continue;

      final staminaFactor = (.55 + p.stamina / 100 * .45).clamp(.55, 1.0);
      final sameTeam = p.team == possessionTeam;
      double targetX;
      double targetY;
      var urgency = .08 + (momentumEdge > 18 ? .025 : momentumEdge < -18 ? -.01 : 0);

      if (sameTeam) {
        final support = _supportTarget(
          player: p,
          owner: owner,
          phase: phase,
          teammates: teammates,
        );
        targetX = support.$1;
        targetY = support.$2;
        targetY += (p.homeY - 50) * (tactical.width - 1.0) * .32;

        final style = TeamPlayStyleProfile.fromManagerStyle(
          p.team == Match2DTeam.home ? homeManagerStyle : awayManagerStyle).style;
        final run = _attackingRuns.choose(
          player: p,
          owner: owner,
          teammates: teammates,
          opponents: opponents,
          phase: phase,
          style: style,
          urgency: tactical.urgency,
          forwardRun: tactical.forwardRun,
          width: tactical.width,
          direction: direction,
          forwardSpace: _forwardSpace(s, owner),
        );
        // Only count meaningful attacking intentions, not every support tick.
        if (run.type != AttackingRunType.support && run.type != AttackingRunType.recovery) {
          if (p.team == Match2DTeam.home) {
            _homeRuns++;
            if (run.separation > 10) _homeDangerousRuns++;
            if (run.type == AttackingRunType.overlap) _homeOverlaps++;
            if (run.type == AttackingRunType.channel) _homeChannelRuns++;
          } else {
            _awayRuns++;
            if (run.separation > 10) _awayDangerousRuns++;
            if (run.type == AttackingRunType.overlap) _awayOverlaps++;
            if (run.type == AttackingRunType.channel) _awayChannelRuns++;
          }
          targetX = targetX * .42 + run.targetX * .58;
          targetY = targetY * .42 + run.targetY * .58;
          urgency = max(urgency, .11 * run.intensity);
        }
        if (p.position == PlayerPosition.defender) {
          targetX += direction * (ownTransitionProfile.lineHeight - .60) * 7.0;
          targetY += (p.homeY - 50) * (1.0 - ownTransitionProfile.compactness) * .20;
        }

        // Make forward runs when the carrier has space. Midfielders support
        // from different depths rather than all following the same point.
        if (p.position == PlayerPosition.striker || p.position == PlayerPosition.winger) {
          final space = _forwardSpace(s, owner);
          if (space > 13) {
            targetX += direction * (p.position == PlayerPosition.striker ? 3.5 : 2.0) * tactical.forwardRun;
            urgency = .13 * tactical.urgency;
          if (tactical.tempo > 1.08) targetX += direction * 1.0;
          }
        }
        // A chasing team compresses the pitch and sends an extra midfielder
        // forward; a protecting team keeps a safer rest-defence shape.
        if (tactical.pushForward && p.position == PlayerPosition.midfielder) {
          targetX += direction * 2.2;
        } else if (tactical.protectLead && p.position == PlayerPosition.defender) {
          targetX -= direction * (1.6 + (1.0 - tactical.defensiveDepth) * 2.0);
        }
      } else {
        final isNearest = nearestDefender?.id == p.id;
        final press = (isNearest && nearestDistance < 17 ||
            (tactical.pressIntensity > 1.20 && nearestDistance < 22 && p.position == PlayerPosition.midfielder) ||
            (opponentTransitionProfile.counterPress > 1.20 && nearestDistance < 19)) &&
            p.position != PlayerPosition.goalkeeper;
        if (press) {
          // Close the carrier from a slight inside angle instead of running
          // directly through him.
          targetX = owner.x - direction * 1.7;
          targetY = owner.y + (p.homeY < owner.y ? -1.2 : 1.2);
          urgency = .18 * tactical.pressIntensity * opponentTransitionProfile.counterPress.clamp(.75, 1.35);
        } else {
          final lane = _coverLaneTarget(p, owner, direction);
          targetX = lane.$1;
          targetY = lane.$2;
          urgency = (p.position == PlayerPosition.defender ? .095 : .075) * tactical.urgency *
              (p.position == PlayerPosition.defender
                  ? opponentTransitionProfile.retreatSpeed
                  : opponentTransitionProfile.runnerTracking);
        }
      }

      if (p.position == PlayerPosition.goalkeeper) {
        // Goalkeeper gets a dedicated depth/angle target instead of following
        // the generic outfield movement rules.
        final home = p.team == Match2DTeam.home;
        final lineX = home ? 4.0 : 96.0;
        final depth = home ? (s.ballX / 100).clamp(0.0, 1.0) : ((100 - s.ballX) / 100).clamp(0.0, 1.0);
        final advance = (depth * 8.0).clamp(0.0, 7.0);
        targetX = home ? lineX + advance : lineX - advance;
        targetY = (50 + (s.ballY - 50) * .32).clamp(5.0, 95.0).toDouble();
        urgency = .12;
      }

      targetX = targetX.clamp(3.0, 97.0).toDouble();
      targetY = targetY.clamp(4.0, 96.0).toDouble();
      final distance = _distanceXY(p.x, p.y, targetX, targetY);
      final moveUrgency = urgency * staminaFactor * (distance > 10 ? 1.25 : 1.0);

      // Acceleration/deceleration is now authoritative. This removes the old
      // frame-to-frame linear teleport feel while preserving the same target
      // positions produced by the tactical layer.
      _movement.apply(p, targetX, targetY, urgency: moveUrgency);
    }
  }

  ({double urgency, double forwardRun, double pressIntensity, bool pushForward, bool protectLead, double width, double defensiveDepth, double tempo}) _tacticalMentality(Match2DState s, Match2DTeam team) {
    final isHome = team == Match2DTeam.home;
    final ownGoals = isHome ? s.homeGoals : s.awayGoals;
    final opponentGoals = isHome ? s.awayGoals : s.homeGoals;
    final goalDiff = ownGoals - opponentGoals;
    final profile = TeamPlayStyleProfile.fromManagerStyle(isHome ? homeManagerStyle : awayManagerStyle);
    var urgency = profile.tempo;
    var forwardRun = profile.forwardRisk;
    var pressIntensity = profile.pressing;
    var width = profile.width;
    var defensiveDepth = profile.defensiveDepth;
    var pushForward = false;
    var protectLead = false;
    if (s.minute >= 70) {
      if (goalDiff < 0) { urgency *= 1.16; forwardRun *= 1.30; pressIntensity *= 1.16; pushForward = true; defensiveDepth = min(1.0, defensiveDepth + .10); }
      else if (goalDiff > 0) { urgency *= .86; forwardRun *= .72; pressIntensity *= .92; protectLead = true; defensiveDepth *= .88; }
      else { urgency *= 1.04; forwardRun *= 1.06; pressIntensity *= 1.04; }
    }
    if (s.minute >= 88 && goalDiff < 0) { urgency *= 1.10; forwardRun *= 1.16; pressIntensity *= 1.10; pushForward = true; defensiveDepth = min(1.0, defensiveDepth + .08); }
    if (profile.style == TeamPlayStyle.highPress && goalDiff >= 0) pressIntensity *= 1.10;
    if (profile.style == TeamPlayStyle.lowBlock && goalDiff >= 0) defensiveDepth *= .82;
    return (urgency: urgency.clamp(.45, 1.70), forwardRun: forwardRun.clamp(.45, 1.90), pressIntensity: pressIntensity.clamp(.45, 1.80), pushForward: pushForward, protectLead: protectLead, width: width.clamp(.70, 1.40), defensiveDepth: defensiveDepth.clamp(.20, 1.0), tempo: profile.tempo);
  }

  void _moveOffBallPlayers(Match2DState s, Match2DPlayer owner, Match2DTeam possessionTeam) {
    for (final p in s.players) {
      if (p.id == owner.id) continue;
      final sameTeam = p.team == possessionTeam;
      final targetX = p.homeX + (owner.x - p.homeX) * (sameTeam ? .12 : .08);
      final targetY = p.homeY + (owner.y - p.homeY) * (sameTeam ? .10 : .06);
      p.x += (targetX - p.x) * .08;
      p.y += (targetY - p.y) * .08;
      if (p.position == PlayerPosition.goalkeeper) {
        p.x += (p.homeX - p.x) * .20;
        p.y += (s.ballY - p.y) * .04;
      }
      p.x = p.x.clamp(3.0, 97.0).toDouble();
      p.y = p.y.clamp(3.0, 97.0).toDouble();
    }
  }
  Match2DPhase _phaseForBall(double x, Match2DTeam team) {
    final distanceToGoal = team == Match2DTeam.home ? 100 - x : x;
    if (distanceToGoal > 60) return Match2DPhase.buildUp;
    if (distanceToGoal > 38) return Match2DPhase.progression;
    if (distanceToGoal > 20) return Match2DPhase.finalThird;
    return Match2DPhase.shot;
  }

  (double, double) _supportTarget({
    required Match2DPlayer player,
    required Match2DPlayer owner,
    required Match2DPhase phase,
    required List<Match2DPlayer> teammates,
  }) {
    final direction = owner.team == Match2DTeam.home ? 1.0 : -1.0;
    var x = player.homeX;
    var y = player.homeY;

    switch (player.position) {
      case PlayerPosition.goalkeeper:
        return (player.homeX, 50);
      case PlayerPosition.defender:
        // Back four shifts with the ball but remains behind it.
        x += (owner.x - x) * .18;
        y += (owner.y - y) * .10;
        break;
      case PlayerPosition.midfielder:
        // Midfielders create triangles: one closer, one wider/deeper.
        final lateral = player.homeY < 50 ? -1.0 : 1.0;
        x += (owner.x - x) * .30;
        y += (owner.y - y) * .22 + lateral * 2.0;
        break;
      case PlayerPosition.winger:
        // Wingers stretch the pitch, especially before the final third.
        x += (owner.x - x) * (phase == Match2DPhase.finalThird ? .28 : .18);
        y += (player.homeY - 50).sign * .5;
        break;
      case PlayerPosition.striker:
        // Striker attacks the space ahead rather than running directly to the
        // ball. This is the main trigger for through-ball situations.
        x += direction * (phase == Match2DPhase.finalThird ? 5.0 : 2.0);
        y += (owner.y - y) * .16;
        break;
    }

    // Role instructions modify the base formation instead of replacing it.
    // This keeps the formation stable while making roles visible in movement.
    switch (player.role) {
      case PlayerRole.attackingFullBack:
        x += direction * 3.5;
        y += (player.homeY - 50) * .06;
        break;
      case PlayerRole.ballPlayingDefender:
        x += direction * 1.0;
        break;
      case PlayerRole.coverDefender:
        x -= direction * 1.8;
        break;
      case PlayerRole.anchor:
        x -= direction * 2.0;
        break;
      case PlayerRole.playmaker:
        x += direction * 1.8;
        y += (50 - player.homeY) * .05;
        break;
      case PlayerRole.boxToBox:
        x += direction * 2.5;
        break;
      case PlayerRole.invertedWinger:
      case PlayerRole.insideForward:
        y += (50 - y) * .18;
        x += direction * 1.8;
        break;
      case PlayerRole.falseNine:
        x -= direction * 5.0;
        break;
      case PlayerRole.targetForward:
        x += direction * 2.5;
        break;
      case PlayerRole.pressingForward:
        x += direction * 2.0;
        break;
      case PlayerRole.poacher:
        x += direction * 1.0;
        break;
      case PlayerRole.wideWinger:
      case PlayerRole.fullBack:
      case PlayerRole.stopper:
      case PlayerRole.goalkeeper:
        break;
    }

    // Avoid bunching: if another teammate is too close, move toward the
    // nearest open side while preserving the player's role.
    final crowded = teammates.where((p) => p.id != player.id).any(
      (p) => _distanceXY(p.x, p.y, x, y) < 7,
    );
    if (crowded && player.position != PlayerPosition.goalkeeper) {
      y += player.homeY < 50 ? -3.5 : 3.5;
    }
    return (x.clamp(3.0, 97.0).toDouble(), y.clamp(5.0, 95.0).toDouble());
  }

  bool _shouldPress(
    Match2DPlayer defender,
    Match2DPlayer owner,
    List<Match2DPlayer> opponents,
  ) {
    if (defender.position == PlayerPosition.goalkeeper) return false;
    final distance = _distanceXY(defender.x, defender.y, owner.x, owner.y);
    if (distance > 15) return false;

    var nearest = double.infinity;
    for (final p in opponents) {
      if (p.id == defender.id) continue;
      nearest = min(nearest, _distanceXY(p.x, p.y, owner.x, owner.y));
    }
    return distance <= nearest + 2.5;
  }

  (double, double) _coverLaneTarget(
    Match2DPlayer defender,
    Match2DPlayer owner,
    double direction,
  ) {
    final x = defender.homeX + (owner.x - defender.homeX) * .14;
    final y = defender.homeY + (owner.y - defender.homeY) * .20;
    return (x - direction * 1.5, y);
  }

  double _forwardSpace(Match2DState s, Match2DPlayer owner) {
    final direction = owner.team == Match2DTeam.home ? 1.0 : -1.0;
    var best = 35.0;
    for (final p in s.players) {
      if (p.team == owner.team) continue;
      final forward = (p.x - owner.x) * direction;
      final lateral = (p.y - owner.y).abs();
      if (forward >= 0 && lateral < 8) best = min(best, forward);
    }
    return best;
  }

  double _teamMinDistance(
      Match2DState s, Match2DTeam team, double x, double y) {
    var best = double.infinity;
    for (final p in s.players) {
      if (p.team != team) continue;
      best = min(best, _distanceXY(p.x, p.y, x, y));
    }
    return best;
  }

  double _distanceXY(double x1, double y1, double x2, double y2) =>
      sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));

  Match2DEvent? _advanceSituation(Match2DState s) {
    final active = _activeSituation;
    if (active == null) return null;
    if (_activeBeat >= active.beats.length) {
      _activeSituation = null;
      _activeSituationId = null;
    _previousBallOwnerId = null;
      _activeBeat = 0;
      return null;
    }

    final beat = active.beats[_activeBeat++];
    final actor = s.players.firstWhere(
      (p) => p.id == beat.actorId,
      orElse: () => s.players.first,
    );
    final secondary = beat.secondaryId == null
        ? null
        : s.players.where((p) => p.id == beat.secondaryId).firstOrNull;

    // Move the ball to the actor of the next beat. This makes the sequence
    // visually readable even before the animation layer becomes richer.
    final currentOwner = s.players.where((p) => p.id == s.ballOwnerId).firstOrNull;
    if (currentOwner != null && currentOwner.id != actor.id) {
      _setOwner(s, currentOwner, actor);
    }

    final isPlayer = actor.id == controlledPlayerId;
    final canKey = isPlayer &&
        _playerKeyMoments < maxPlayerKeyMoments &&
        s.minute - _lastPlayerKeyMinute >= 6 &&
        (beat.isChance || beat.type == Match2DEventType.tackle);

    if (canKey) {
      final mini = _miniGameFor(beat.type, actor.position);
      if (mini != null) {
        return _keyEvent(
          type: beat.type,
          player: actor,
          secondary: secondary,
          description: beat.description,
          miniGameType: mini,
          x: actor.x,
          y: actor.y,
          s: s,
          situationId: _activeSituationId,
          situationBeat: _activeBeat - 1,
          isChance: beat.isChance,
        );
      }
    }

    // AI resolves non-player beats immediately, so a headless match can use
    // the exact same sequence without needing a UI interaction.
    _resolveAIAttackBeat(s, actor, secondary, beat);
    final event = Match2DEvent(
      type: beat.type,
      playerId: actor.id,
      secondaryPlayerId: secondary?.id,
      description: beat.description,
      minute: s.minute,
      x: s.ballX,
      y: s.ballY,
      isKeyMoment: false,
      situationId: _activeSituationId,
      situationBeat: _activeBeat - 1,
      isChance: beat.isChance,
    );
    _recordEventStats(s, event: event.type, team: actor.team, keyMoment: false);
    _events.add(event);
    return event;
  }

  String? _miniGameFor(Match2DEventType type, PlayerPosition position) {
    final base = switch (type) {
      Match2DEventType.shot when position != PlayerPosition.goalkeeper => 'shot',
      Match2DEventType.pass || Match2DEventType.cross => 'pass',
      Match2DEventType.dribble => 'dribble',
      Match2DEventType.tackle => 'tackle',
      Match2DEventType.save => 'save',
      _ => null,
    };
    if (base == null) return null;
    // Variant selection is deterministic from the situation context, so the
    // same position can receive five genuinely different mini-game prompts.
    final seed = (_activeBeat + sMinuteSeed) % 5;
    const variants = {
      'shot': ['shotPlacement', 'shotPower', 'shotFirstTime', 'shotOneOnOne', 'shotVolley'],
      'pass': ['passThroughBall', 'passQuickOneTwo', 'passCross', 'passSwitch', 'passFinalBall'],
      'dribble': ['dribbleInside', 'dribbleOutside', 'dribbleStopGo', 'dribbleBodyFeint', 'dribbleCounter'],
      'tackle': ['tackleFront', 'tackleSide', 'tackleRecovery', 'tackleInterception', 'tackleLastMan'],
      'save': ['saveGround', 'saveHigh', 'saveNearPost', 'saveOneOnOne', 'savePenalty'],
    };
    return '$base:${variants[base]![seed]}';
  }

  int get sMinuteSeed => state?.minute ?? 0;

  void _resolveAIAttackBeat(
    Match2DState s,
    Match2DPlayer actor,
    Match2DPlayer? secondary,
    MatchSituationBeat beat,
  ) {
    switch (beat.type) {
      case Match2DEventType.pass:
      case Match2DEventType.cross:
        _transferBall(s, actor);
        break;
      case Match2DEventType.dribble:
        final defender = secondary ?? _nearestOpponent(s, actor);
        final duel = _duels.dribble(
          attacker: actor,
          defender: defender,
          space: _forwardSpace(s, actor),
        );
        if (duel.won) {
          _moveAfterDribble(s, actor);
        } else {
          _transferBall(s, actor, toOpponent: true);
        }
        break;
      case Match2DEventType.shot:
        if (_resolveShot(s, actor)) {
          // goal already registered
        } else {
          _transferBall(s, actor, toOpponent: true);
        }
        break;
      default:
        break;
    }
  }

  Match2DEvent? _maybeGuaranteedPlayerMoment(Match2DState s) {
    final controlled = _controlledPlayer(s);
    if (controlled == null || _playerKeyMoments >= maxPlayerKeyMoments) return null;
    if (_guaranteedMomentIndex >= _guaranteedMomentMinutes.length) return null;
    if (s.minute < _guaranteedMomentMinutes[_guaranteedMomentIndex]) return null;
    if (s.minute - _lastPlayerKeyMinute < 6) return null;

    _guaranteedMomentIndex++;
    final isHome = controlled.team == Match2DTeam.home;
    final direction = isHome ? 1.0 : -1.0;

    // Nigdy nie teleportujemy zawodnika do gotowej sceny. Kluczowy moment
    // powstaje w jego aktualnym miejscu na boisku, a animacja ruchu dalej
    // prowadzi akcję. Dzięki temu pozycja pionka pozostaje wiarygodna.
    if (controlled.position == PlayerPosition.goalkeeper) {
      final shooter = s.players
          .where((p) => p.team != controlled.team && p.position != PlayerPosition.goalkeeper)
          .toList()
        ..sort((a, b) => b.overall.compareTo(a.overall));
      final opponent = shooter.isNotEmpty ? shooter.first : _nearestOpponent(s, controlled);
      _setOwner(s, opponent, controlled);
      return _keyEvent(
        type: Match2DEventType.save,
        player: controlled,
        secondary: opponent,
        description: '${opponent.name} oddaje strzał — czas na interwencję',
        miniGameType: 'save',
        x: opponent.x,
        y: opponent.y,
        s: s,
        isChance: true,
      );
    }

    // Put the player on the ball so the mini-game is always a real football
    // situation rather than a disconnected popup.
    for (final p in s.players) p.hasBall = false;
    controlled.hasBall = true;
    s.ballOwnerId = controlled.id;
    s.ballTargetOwnerId = null;
    s.ballTravelProgress = 1.0;
    s.ballX = controlled.x;
    s.ballY = controlled.y;
    s.ballVelocityX = 0;
    s.ballVelocityY = 0;
    s.ballHeight = 0;

    final distanceToGoal = controlled.team == Match2DTeam.home
        ? 100 - controlled.x
        : controlled.x;
    final opponent = _nearestOpponent(s, controlled);
    final type = controlled.position == PlayerPosition.striker ||
            (controlled.position == PlayerPosition.winger && distanceToGoal < 30)
        ? Match2DEventType.shot
        : controlled.position == PlayerPosition.winger
            ? Match2DEventType.dribble
            : Match2DEventType.pass;
    final mini = switch (type) {
      Match2DEventType.shot => 'shot',
      Match2DEventType.dribble => 'dribble',
      _ => 'pass',
    };
    final text = switch (type) {
      Match2DEventType.shot => '${controlled.name} dostaje piłkę w polu karnym',
      Match2DEventType.dribble => '${controlled.name} rusza z piłką na rywala',
      _ => '${controlled.name} ma otwierające podanie',
    };
    return _keyEvent(
      type: type,
      player: controlled,
      secondary: opponent,
      description: text,
      miniGameType: mini,
      x: controlled.x,
      y: controlled.y,
      s: s,
      isChance: true,
    );
  }

  Match2DEvent? _maybeAction(Match2DState s) {
    final owner = s.players.firstWhere(
      (p) => p.id == s.ballOwnerId && p.active,
      orElse: () => s.players.firstWhere((p) => p.active, orElse: () => s.players.first),
    );
    final opponents = s.players.where((p) => p.active && p.team != owner.team).toList();
    final teammates = s.players.where((p) => p.active && p.team == owner.team && p.id != owner.id).toList();
    final nearestOpponent = opponents.isEmpty ? null : opponents.reduce(
      (a, b) => _distanceXY(a.x, a.y, owner.x, owner.y) < _distanceXY(b.x, b.y, owner.x, owner.y) ? a : b,
    );
    final bestTeammate = teammates.isEmpty ? null : _bestPassTarget(owner, teammates);
    final pressure = _nearestOpponentDistance(safePlayers: s.players, player: owner);
    final forwardSpace = _forwardSpace(s, owner);
    final distanceToGoal = owner.team == Match2DTeam.home ? 100 - owner.x : owner.x;
    final goalDiff = owner.team == Match2DTeam.home ? s.homeGoals - s.awayGoals : s.awayGoals - s.homeGoals;
    final losing = goalDiff < 0;
    final leading = goalDiff > 0;
    final momentum = _momentum.evaluate(state: s, events: _events, possessionTeam: owner.team == Match2DTeam.home ? 'home' : 'away');
    final momentumEdge = owner.team == Match2DTeam.home ? momentum.homeEdge : momentum.awayEdge;
    final momentumBoost = losing ? (momentumEdge < -18 ? .14 : 0.0) : (momentumEdge > 22 ? -.05 : 0.0);
    final urgency = (losing ? (s.minute >= 88 ? 1.35 : s.minute >= 70 ? 1.15 : .85) : leading ? (s.minute >= 80 ? 1.15 : .65) : .8) + momentumBoost;
    final context = MatchPlayerDecisionContext(
      player: owner,
      nearestOpponent: nearestOpponent,
      bestTeammate: bestTeammate,
      pressure: pressure,
      forwardSpace: forwardSpace,
      distanceToGoal: distanceToGoal,
      scoreUrgency: urgency,
      transitionUrgency: losing ? 1.2 : .8,
      inFinalThird: distanceToGoal < 38,
      losing: losing,
      leading: leading,
      underHeavyPressure: pressure < 5.5,
    );
    final decision = _playerDecisions.choose(context);

    // Keep the live match readable: not every simulation beat becomes an event.
    if (random.nextDouble() > .30) return null;

    Match2DEventType type;
    String text;
    switch (decision.action) {
      case MatchPlayerDecisionAction.shoot:
        type = Match2DEventType.shot;
        text = '${owner.name} oddaje strzał (${decision.reason})';
        break;
      case MatchPlayerDecisionAction.cross:
        type = Match2DEventType.cross;
        text = '${owner.name} dośrodkowuje (${decision.reason})';
        break;
      case MatchPlayerDecisionAction.dribble:
        type = Match2DEventType.dribble;
        text = '${owner.name} próbuje dryblingu (${decision.reason})';
        break;
      case MatchPlayerDecisionAction.carry:
        type = Match2DEventType.dribble;
        text = '${owner.name} prowadzi piłkę (${decision.reason})';
        break;
      case MatchPlayerDecisionAction.clear:
        type = Match2DEventType.clearance;
        text = '${owner.name} wybija piłkę (${decision.reason})';
        break;
      case MatchPlayerDecisionAction.recycle:
      case MatchPlayerDecisionAction.pass:
        type = Match2DEventType.pass;
        text = '${owner.name} zagrywa piłkę (${decision.reason})';
        break;
    }

    if (type == Match2DEventType.shot) {
      final goal = _resolveShot(s, owner);
      if (goal) {
        type = Match2DEventType.goal;
        text = 'GOOOL! ${owner.name} trafia do siatki';
      } else {
        type = Match2DEventType.save;
        text = 'Bramkarz broni strzał ${owner.name}';
        _transferBall(s, owner, toOpponent: true);
      }
    } else if (type == Match2DEventType.dribble) {
      final defender = nearestOpponent;
      if (defender != null && _distanceXY(defender.x, defender.y, owner.x, owner.y) < 14) {
        final duel = _duels.tackle(defender: defender, attacker: owner, distance: pressure);
        if (duel.won) {
          _moveAfterDribble(s, owner);
        } else {
          _transferBall(s, owner, toOpponent: true);
          type = Match2DEventType.tackle;
          text = '${defender.name} zatrzymuje ${owner.name}';
        }
      } else {
        _moveAfterDribble(s, owner);
      }
    } else if (type == Match2DEventType.clearance) {
      _transferBall(s, owner, toOpponent: true);
    } else {
      _transferBall(s, owner, toOpponent: false);
    }

    _recordEventStats(s, event: type, team: owner.team, keyMoment: false);
    final event = Match2DEvent(
      type: type,
      playerId: owner.id,
      secondaryPlayerId: nearestOpponent?.id,
      description: text,
      minute: s.minute,
      x: s.ballX,
      y: s.ballY,
    );
    _events.add(event);
    return event;
  }

  Match2DEvent _keyEvent({
    required Match2DEventType type,
    required Match2DPlayer player,
    Match2DPlayer? secondary,
    required String description,
    required String miniGameType,
    required double x,
    required double y,
    required Match2DState s,
    String? situationId,
    int situationBeat = 0,
    bool isChance = false,
  }) {
    _playerKeyMoments++;
    _lastPlayerKeyMinute = s.minute;

    final event = Match2DEvent(
      type: type,
      playerId: player.id,
      secondaryPlayerId: secondary?.id,
      description: description,
      minute: s.minute,
      x: x,
      y: y,
      isKeyMoment: true,
      miniGameType: miniGameType,
      situationId: situationId,
      situationBeat: situationBeat,
      isChance: isChance,
    );
    _recordEventStats(s, event: type, team: player.team, keyMoment: true);
    _events.add(event);
    return event;
  }

  Match2DPlayer? _controlledPlayer(Match2DState s) {
    final id = controlledPlayerId;
    if (id == null) return null;
    for (final p in s.players) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _placeGoalPosition(Match2DState s, bool isHome, Match2DPlayer scorer) {
    final goalX = isHome ? 96.0 : 4.0;
    final goalY = (50.0 + (random.nextDouble() - .5) * 24.0).clamp(30.0, 70.0);
    scorer.x = goalX - (isHome ? 4.0 : -4.0);
    scorer.y = goalY;
    for (final p in s.players) p.hasBall = false;
    scorer.hasBall = true;
    s.ballOwnerId = scorer.id;
    s.ballTargetOwnerId = null;
    s.ballTravelProgress = 1.0;
    s.ballX = goalX;
    s.ballY = goalY;
  }

  Match2DEvent? _materializeScheduledGoal(Match2DState s) {
    final homeDue = _isScheduledGoalMinute(s.minute, true) &&
        s.targetHomeGoals != null && s.homeGoals < s.targetHomeGoals!;
    final awayDue = _isScheduledGoalMinute(s.minute, false) &&
        s.targetAwayGoals != null && s.awayGoals < s.targetAwayGoals!;
    if (!homeDue && !awayDue) return null;

    final home = homeDue && (!awayDue || random.nextBool());
    final scorer = _bestAttacker(s, home ? Match2DTeam.home : Match2DTeam.away);
    _placeGoalPosition(s, home, scorer);
    _registerGoal(s, home);
    final event = Match2DEvent(
      type: Match2DEventType.goal,
      playerId: scorer.id,
      description: 'GOOOL! ${scorer.name} trafia po dobrze rozegranej akcji',
      minute: s.minute,
      x: scorer.x,
      y: scorer.y,
      isKeyMoment: false,
    );
    _events.add(event);
    _recordEventStats(s, event: event.type, team: scorer.team, keyMoment: false);
    return event;
  }

  bool _resolveShot(Match2DState s, Match2DPlayer shooter) {
    final home = shooter.team == Match2DTeam.home;
    final target = home ? s.targetHomeGoals : s.targetAwayGoals;
    final current = home ? s.homeGoals : s.awayGoals;
    final defendingTeam = shooter.team == Match2DTeam.home ? Match2DTeam.away : Match2DTeam.home;
    final assessment = _chances.assess(
      state: s,
      shooter: shooter,
      attackingStrength: _teamStrength(s, shooter.team),
      defendingStrength: _teamStrength(s, defendingTeam),
      managerStyle: home ? homeManagerStyle : awayManagerStyle,
    );
    final keeper = _goalkeepers.goalkeeper(s, defendingTeam);
    final keeperAssessment = keeper == null
        ? null
        : _goalkeepers.assess(state: s, goalkeeper: keeper, shooter: shooter);
    _expectedGoals += assessment.xG;
    if (home) {
      _expectedGoalsHome += assessment.xG;
    } else {
      _expectedGoalsAway += assessment.xG;
    }

    // The pre-match target remains compatibility authority for now, but shot
    // quality gates it. This is an intentional bridge toward full gameplay
    // result authority in the later migration phase.
    if (target != null) {
      if (current >= target) return false;
      final minutesLeft = max(1, 90 - s.minute);
      final goalsLeft = target - current;
      final scheduled = _isScheduledGoalMinute(s.minute, home);
      final mustScore = goalsLeft >= (minutesLeft ~/ 8) + 1;
      final pressureBonus = scheduled || mustScore ? 1.25 : 0.75;
      if (assessment.xG < .045) return false;
      final keeperModifier = keeperAssessment == null
          ? 1.0
          : (1.0 - keeperAssessment.saveProbability * .72).clamp(.48, 1.0);
      if (_chances.resolveGoal(assessment, authorityModifier: pressureBonus * keeperModifier)) {
        _placeGoalPosition(s, home, shooter);
        _registerGoal(s, home);
        return true;
      }
      return false;
    }

    final keeperModifier = keeperAssessment == null
        ? 1.0
        : (1.0 - keeperAssessment.saveProbability * .72).clamp(.48, 1.0);
    if (_chances.resolveGoal(assessment, authorityModifier: keeperModifier)) {
      _placeGoalPosition(s, home, shooter);
      _registerGoal(s, home);
      return true;
    }
    return false;
  }

  double _teamStrength(Match2DState s, Match2DTeam team) {
    final players = s.players.where((p) =>
        p.team == team && p.active && !p.redCard && p.position != PlayerPosition.goalkeeper);
    if (players.isEmpty) return 70;
    var total = 0.0;
    var count = 0;
    for (final player in players) {
      total += player.overall;
      count++;
    }
    return (total / count).clamp(1, 99);
  }

  bool _isScheduledGoalMinute(int minute, bool home) {
    final list = home ? _homeGoalMinutes : _awayGoalMinutes;
    return list.contains(minute);
  }

  Match2DEvent? _forceSyncFinalScore(Match2DState s) {
    Match2DEvent? last;
    while (s.targetHomeGoals != null &&
        s.homeGoals < s.targetHomeGoals!) {
      final scorer = _bestAttacker(s, Match2DTeam.home);
      _placeGoalPosition(s, true, scorer);
      _registerGoal(s, true);
      last = Match2DEvent(
        type: Match2DEventType.goal,
        playerId: scorer.id,
        description: 'GOOOL! ${scorer.name} trafia w końcówce',
        minute: s.minute,
        x: s.ballX,
        y: s.ballY,
        isKeyMoment: false,
      );
      _events.add(last);
    }
    while (s.targetAwayGoals != null &&
        s.awayGoals < s.targetAwayGoals!) {
      final scorer = _bestAttacker(s, Match2DTeam.away);
      _placeGoalPosition(s, false, scorer);
      _registerGoal(s, false);
      last = Match2DEvent(
        type: Match2DEventType.goal,
        playerId: scorer.id,
        description: 'GOOOL! ${scorer.name} trafia w końcówce',
        minute: s.minute,
        x: s.ballX,
        y: s.ballY,
        isKeyMoment: false,
      );
      _events.add(last);
    }
    return last;
  }

  Match2DPlayer _bestAttacker(Match2DState s, Match2DTeam team) {
    final candidates = s.players
        .where((p) =>
            p.active && p.team == team &&
            p.position != PlayerPosition.goalkeeper)
        .toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    return candidates.isNotEmpty ? candidates.first : s.players.first;
  }

  void _registerGoal(Match2DState s, bool isHome) {
    if (isHome) {
      s.homeGoals++;
      _resultAuthority.recordGoal(home: true);
    } else {
      s.awayGoals++;
      _resultAuthority.recordGoal(home: false);
    }
  }

  /// Resolves the pending player action after a mini-game.
  ///
  /// For official league fixtures the target result is still a hard ceiling:
  /// the visual match cannot create a table result different from the league
  /// engine. The mini-game decides whether the player's opportunity succeeds.
  int get finalHomeGoals => state?.homeGoals ?? 0;
  int get finalAwayGoals => state?.awayGoals ?? 0;

  /// Difference between the pre-match estimate and what happened after
  /// interactive player actions.
  int get interactiveHomeDelta => _interactiveHomeDelta;
  int get interactiveAwayDelta => _interactiveAwayDelta;

  /// Builds the controlled player's real match line from the events that
  /// actually happened in the 2D match. The career layer consumes this instead
  /// of inventing a second, unrelated performance after the final whistle.
  /// Aggregate expected goals generated by the live chance model. This is a
  /// diagnostic gameplay metric and never replaces the result authority.
  double get expectedGoals => _expectedGoals;

  double get expectedGoalsHome => _expectedGoalsHome;

  double get expectedGoalsAway => _expectedGoalsAway;

  MatchMomentumSnapshot get momentumSnapshot => _momentum.evaluate(
    state: state!, events: _events, possessionTeam: state?.ballOwnerId == null ? null :
      (state!.players.firstWhere((p) => p.id == state!.ballOwnerId, orElse: () => state!.players.first).team == Match2DTeam.home ? 'home' : 'away'));

  TeamPassingNetworkSnapshot get passingNetworkHome => _passingNetwork.homeSnapshot();

  TeamPassingNetworkSnapshot get passingNetworkAway => _passingNetwork.awaySnapshot();

  GameplayResultSnapshot get gameplayResultSnapshot => _resultAuthority.snapshot(
        homeGoals: state?.homeGoals ?? 0,
        awayGoals: state?.awayGoals ?? 0,
      );

  PlayerMatchPerformance? performanceForPlayer(String playerId) {
    final s = state;
    if (s == null) return null;
    final player = s.players.where((p) => p.id == playerId).firstOrNull ??
        s.benchPlayers.where((p) => p.id == playerId).firstOrNull;
    if (player == null) return null;
    final minutes = player.minutesPlayed > 0
        ? player.minutesPlayed
        : (_startingPlayerIds.contains(playerId) ? min(90, s.minute) : 0);
    if (minutes <= 0) return null;
    final playerEvents = _events.where((e) => e.playerId == playerId).toList();
    final goals = playerEvents.where((e) => e.type == Match2DEventType.goal).length;
    final assists = 0;
    final shots = playerEvents.where((e) => e.type == Match2DEventType.shot).length + goals;
    final onTarget = goals + playerEvents.where((e) => e.type == Match2DEventType.save).length;
    final passes = playerEvents.where((e) => e.type == Match2DEventType.pass || e.type == Match2DEventType.cross).length;
    final dribbles = playerEvents.where((e) => e.type == Match2DEventType.dribble).length;
    final tackles = playerEvents.where((e) => e.type == Match2DEventType.tackle || e.type == Match2DEventType.interception).length;
    final yellows = playerEvents.where((e) => e.type == Match2DEventType.card && player.yellowCard).length;
    final reds = player.redCard ? 1 : 0;
    var rating = 6.2 + goals * .8 + passes * .025 + dribbles * .05 + tackles * .04;
    if (yellows > 0) rating -= .35;
    if (reds > 0) rating -= 1.2;
    return PlayerMatchPerformance(
      playerId: playerId,
      minutes: minutes,
      started: _startingPlayerIds.contains(playerId),
      rating: rating.clamp(4.5, 10.0).toDouble(),
      goals: goals,
      shots: shots,
      shotsOnTarget: min(shots, onTarget),
      keyPasses: passes ~/ 3,
      successfulDribbles: dribbles,
      yellowCards: yellows,
      redCards: reds,
    );
  }

  Match2DEvent? applyMiniGameOutcome(
    Match2DEvent originalEvent,
    bool success,
  ) {
    final s = state;
    if (s == null || !originalEvent.isKeyMoment) return null;

    final actor = s.players.firstWhere(
      (p) => p.id == originalEvent.playerId,
      orElse: () => s.players.first,
    );

    Match2DEvent result;

    switch (originalEvent.miniGameType) {
      case 'shot':
        final home = actor.team == Match2DTeam.home;
        final target = home ? s.targetHomeGoals : s.targetAwayGoals;
        final current = home ? s.homeGoals : s.awayGoals;
        // Gameplay authority has no fixture ceiling. Legacy mode keeps the
        // historical +1 interactive bridge so league results remain safe.
        final budgetLeft = gameplayResultAuthority
            ? true
            : current < ((target ?? 0) + 1);

        if (success && budgetLeft) {
          _placeGoalPosition(s, home, actor);
          _registerGoal(s, home);
          if (home) {
            _interactiveHomeDelta++;
          } else {
            _interactiveAwayDelta++;
          }
          result = Match2DEvent(
            type: Match2DEventType.goal,
            playerId: actor.id,
            secondaryPlayerId: originalEvent.secondaryPlayerId,
            description: 'GOOOL! ${actor.name} wykorzystuje okazję!',
            minute: s.minute,
            x: s.ballX,
            y: s.ballY,
            isKeyMoment: true,
          );
        } else {
          _transferBall(s, actor, toOpponent: true);
          _breakActiveSituation();
          result = Match2DEvent(
            type: Match2DEventType.save,
            playerId: actor.id,
            secondaryPlayerId: originalEvent.secondaryPlayerId,
            description: 'Bramkarz zatrzymuje strzał ${actor.name}',
            minute: s.minute,
            x: s.ballX,
            y: s.ballY,
            isKeyMoment: true,
          );
        }
        break;

      case 'pass':
        if (success) {
          _transferBall(s, actor);
          // Successful execution keeps the current situation alive. The next
          // tick advances to its next beat (receiver, cross, finish, etc.).
          result = _resultEvent(
            originalEvent,
            Match2DEventType.pass,
            '${actor.name} zagrywa idealną piłkę',
          );
        } else {
          _transferBall(s, actor, toOpponent: true);
          _breakActiveSituation();
          result = _resultEvent(
            originalEvent,
            Match2DEventType.interception,
            'Podanie ${actor.name} zostaje przecięte',
          );
        }
        break;

      case 'dribble':
        final defender = _nearestOpponent(s, actor);
        if (success) {
          _moveAfterDribble(s, actor);
          // A successful duel opens the next branch of the same attack.
          result = _resultEvent(
            originalEvent,
            Match2DEventType.dribble,
            '${actor.name} mija rywala',
          );
        } else {
          _transferBall(s, actor, toOpponent: true);
          _breakActiveSituation();
          result = _resultEvent(
            originalEvent,
            Match2DEventType.tackle,
            '${defender.name} odbiera piłkę',
          );
        }
        break;

      case 'tackle':
        if (success) {
          final opponent = _nearestOpponent(s, actor);
          for (final p in s.players) p.hasBall = false;
          s.ballOwnerId = null;
          s.ballTargetOwnerId = null;
          s.ballTravelProgress = 1.0;
          s.ballX = (s.ballX + actor.x + opponent.x) / 3;
          s.ballY = (s.ballY + actor.y + opponent.y) / 3;
          final awayX = actor.x - opponent.x;
          final awayY = actor.y - opponent.y;
          final awayLength = sqrt(awayX * awayX + awayY * awayY);
          final dirX = awayLength > .1 ? awayX / awayLength : (actor.team == Match2DTeam.home ? 1.0 : -1.0);
          final dirY = awayLength > .1 ? awayY / awayLength : .15;
          s.ballVelocityX = dirX * (18 + actor.overall * .08);
          s.ballVelocityY = dirY * (18 + actor.overall * .08);
          s.ballHeight = 0;
          s.ballSpin = dirX * 3.5;
          s.ballBounce = .75;
          _looseBallTime = .72;
          result = _resultEvent(
            originalEvent,
            Match2DEventType.tackle,
            '${actor.name} świetnie odbiera piłkę — futbolówka odskakuje',
          );
        } else {
          final opponent = _nearestOpponent(s, actor);
          _breakActiveSituation();
          result = _resultEvent(
            originalEvent,
            Match2DEventType.dribble,
            '${opponent.name} wychodzi spod pressingu',
          );
        }
        break;

      case 'save':
        // For a save, actor is the goalkeeper and secondary is the shooter.
        final home = actor.team == Match2DTeam.home;
        final target = home ? s.targetAwayGoals : s.targetHomeGoals;
        final current = home ? s.awayGoals : s.homeGoals;
        final budgetLeft = target == null || current < target;

        if (success) {
          // A great goalkeeper intervention can cancel one expected AI goal.
          // We do not rewrite the whole match; we only remove one pending
          // goal from this team's baseline if one is still available.
          final opponentGoals = home ? _homeGoalMinutes : _awayGoalMinutes;
          final resolved = home
              ? _resolvedScheduledGoalsAway
              : _resolvedScheduledGoalsHome;
          final pending = opponentGoals.where((m) => !resolved.contains(m)).toList();
          if (pending.isNotEmpty) {
            resolved.add(pending.last);
            _missedPlayerGoals++;
          }
          _transferBall(s, actor, toOpponent: false);
          _breakActiveSituation();
          result = _resultEvent(
            originalEvent,
            Match2DEventType.save,
            '${actor.name} broni strzał!',
          );
        } else if (budgetLeft) {
          final shooter = _nearestOpponent(s, actor);
          _placeGoalPosition(s, !home, shooter);
          _registerGoal(s, !home);
          _breakActiveSituation();
          result = Match2DEvent(
            type: Match2DEventType.goal,
            playerId: shooter.id,
            secondaryPlayerId: actor.id,
            description: 'GOOOL! Bramkarz nie zdołał obronić',
            minute: s.minute,
            x: s.ballX,
            y: s.ballY,
            isKeyMoment: true,
          );
          _events.add(result);
        } else {
          _transferBall(s, actor, toOpponent: false);
          _breakActiveSituation();
          result = _resultEvent(
            originalEvent,
            Match2DEventType.save,
            '${actor.name} broni strzał',
          );
        }
        break;

      default:
        _transferBall(s, actor);
        result = _resultEvent(
          originalEvent,
          originalEvent.type,
          '${actor.name} wykonuje akcję',
        );
    }

    _events.add(result);
    return result;
  }

  Match2DEvent _resultEvent(
    Match2DEvent original,
    Match2DEventType type,
    String description,
  ) =>
      Match2DEvent(
        type: type,
        playerId: original.playerId,
        secondaryPlayerId: original.secondaryPlayerId,
        description: description,
        minute: original.minute,
        x: original.x,
        y: original.y,
        isKeyMoment: true,
        situationId: original.situationId,
        situationBeat: original.situationBeat,
        isChance: original.isChance,
      );

  void _breakActiveSituation() {
    _activeSituation = null;
    _activeSituationId = null;
    _previousBallOwnerId = null;
    _activeBeat = 0;
  }


  ({double velocityX, double velocityY, double offsetX, double offsetY, double bounce, double spin})
      _calculateContactDeflection(
    Match2DState s, {
    required Match2DPlayer collider,
    required double incomingX,
    required double incomingY,
    required bool controlled,
    double touchRetention = 0.5,
  }) {
    // Convert the incoming ball velocity into a contact-space vector. The
    // normal points from the player toward the ball, so reflecting against it
    // gives a stable, readable deflection rather than a random bounce.
    var nx = s.ballX - collider.x;
    var ny = s.ballY - collider.y;
    final normalLength = sqrt(nx * nx + ny * ny);
    if (normalLength < 0.001) {
      final incomingLength = sqrt(incomingX * incomingX + incomingY * incomingY);
      nx = incomingLength > 0.001 ? incomingX / incomingLength : 1.0;
      ny = incomingLength > 0.001 ? incomingY / incomingLength : 0.0;
    } else {
      nx /= normalLength;
      ny /= normalLength;
    }

    final speed = sqrt(incomingX * incomingX + incomingY * incomingY);
    final safeSpeed = speed.clamp(3.0, 30.0).toDouble();
    final dot = incomingX * nx + incomingY * ny;
    final reflectedX = incomingX - 2 * dot * nx;
    final reflectedY = incomingY - 2 * dot * ny;
    final reflectedLength = sqrt(reflectedX * reflectedX + reflectedY * reflectedY);

    // Better control reduces rebound energy. Higher overall gives a softer
    // first touch, while an uncontrolled interception keeps more momentum.
    final control = (collider.overall / 100.0).clamp(.45, .95);
    final retention = ((controlled ? (.10 + control * .16) : (.34 + control * .20)) * (0.65 + touchRetention * .55)).clamp(.08, .72);
    final tangentialX = incomingX - dot * nx;
    final tangentialY = incomingY - dot * ny;
    final tangentLength = sqrt(tangentialX * tangentialX + tangentialY * tangentialY);

    double vx;
    double vy;
    if (reflectedLength < 0.001) {
      vx = nx * safeSpeed * retention;
      vy = ny * safeSpeed * retention;
    } else {
      // Blend reflection with tangential carry so glancing contacts visibly
      // travel across the pitch instead of stopping dead.
      final reflectionWeight = controlled ? .28 : .58;
      vx = (reflectedX / reflectedLength) * safeSpeed * reflectionWeight;
      vy = (reflectedY / reflectedLength) * safeSpeed * reflectionWeight;
      if (tangentLength > .001) {
        vx += (tangentialX / tangentLength) * safeSpeed * (1 - reflectionWeight) * retention;
        vy += (tangentialY / tangentLength) * safeSpeed * (1 - reflectionWeight) * retention;
      }
    }

    final outLength = sqrt(vx * vx + vy * vy);
    final normalizedVx = outLength > .001 ? vx / outLength : nx;
    final normalizedVy = outLength > .001 ? vy / outLength : ny;
    final touchDistance = controlled ? .38 : .62;

    return (
      velocityX: normalizedVx * outLength.clamp(1.2, 12.0),
      velocityY: normalizedVy * outLength.clamp(1.2, 12.0),
      offsetX: normalizedVx * touchDistance,
      offsetY: normalizedVy * touchDistance,
      bounce: controlled ? .82 : 1.0,
      spin: (collider.overall / 100.0) * (controlled ? .65 : 1.15),
    );
  }

  Match2DPlayer? _findBallCollider(
    Match2DState s, {
    Set<String> excludeIds = const <String>{},
    String? preferredId,
  }) {
    // Contact is only possible while the ball is close enough to the player's
    // feet/body plane. High balls continue travelling above the collider.
    if (s.ballHeight > 3.2) return null;

    final candidates = s.players.where((p) =>
        p.active && !excludeIds.contains(p.id) &&
        _distanceXY(p.x, p.y, s.ballX, s.ballY) <= 3.25).toList();
    if (candidates.isEmpty) return null;

    // Prefer the intended receiver when both players overlap the contact
    // radius. Otherwise the closest active player wins the collision.
    candidates.sort((a, b) {
      if (a.id == preferredId) return -1;
      if (b.id == preferredId) return 1;
      return _distanceXY(a.x, a.y, s.ballX, s.ballY)
          .compareTo(_distanceXY(b.x, b.y, s.ballX, s.ballY));
    });
    return candidates.first;
  }

  Match2DPlayer _nearestOpponent(Match2DState s, Match2DPlayer actor) {
    final opponents = s.players.where((p) => p.active && p.team != actor.team).toList();
    opponents.sort((a, b) => _distanceXY(a.x, a.y, actor.x, actor.y)
        .compareTo(_distanceXY(b.x, b.y, actor.x, actor.y)));
    return opponents.first;
  }

  void _moveAfterDribble(Match2DState s, Match2DPlayer actor) {
    final dir = actor.team == Match2DTeam.home ? 1.0 : -1.0;
    actor.x = (actor.x + dir * 6).clamp(3.0, 97.0).toDouble();
    s.ballX = actor.x;
    s.ballY = actor.y;
  }

  void _transferBall(
    Match2DState s,
    Match2DPlayer owner, {
    bool toOpponent = false,
  }) {
    final pool = toOpponent
        ? s.players.where((p) => p.active && p.team != owner.team).toList()
        : s.players
            .where((p) => p.active && p.team == owner.team && p.id != owner.id)
            .toList();

    if (pool.isEmpty) return;

    // A controlled player gets a slightly higher chance of receiving normal
    // passes. This creates more playable moments without forcing possession.
    if (!toOpponent && controlledPlayerId != null) {
      final controlled = pool.where((p) => p.id == controlledPlayerId).firstOrNull;
      if (controlled != null && random.nextDouble() < .20) {
        _setOwner(s, owner, controlled);
        return;
      }
    }

    pool.sort(
      (a, b) => _distanceXY(a.x, a.y, s.ballX, s.ballY)
          .compareTo(_distanceXY(b.x, b.y, s.ballX, s.ballY)),
    );

    final target = toOpponent
        ? pool.first
        : _bestPassTarget(owner, pool);

    if (toOpponent) {
      _passingNetwork.turnover(owner.team == Match2DTeam.home);
    } else {
      final distance = _distanceXY(owner.x, owner.y, target.x, target.y);
      final direction = owner.team == Match2DTeam.home ? 1.0 : -1.0;
      final forwardProgress = (target.x - owner.x) * direction;
      _passingNetwork.pass(home: owner.team == Match2DTeam.home, distance: distance, forwardProgress: forwardProgress, targetY: target.y);
      final ownerFinal = (owner.x * direction + 100) / 2;
      final targetFinal = (target.x * direction + 100) / 2;
      if (ownerFinal < 62 && targetFinal >= 62) {
        _passingNetwork.finalThirdEntry(owner.team == Match2DTeam.home);
      }
    }
    _setOwner(s, owner, target);
  }

  Match2DPlayer _bestPassTarget(
      Match2DPlayer owner, List<Match2DPlayer> pool) {
    final dir = owner.team == Match2DTeam.home ? 1.0 : -1.0;
    pool.sort((a, b) {
      double score(Match2DPlayer p) {
        final forward = (p.x - owner.x) * dir;
        final distance = _distanceXY(p.x, p.y, owner.x, owner.y);
        final pressure = _nearestOpponentDistance(safePlayers: state!.players, player: p);
        final width = (p.y - 50).abs();
        final roleBonus = switch (p.position) {
          PlayerPosition.striker => 5.0,
          PlayerPosition.winger => 3.0,
          PlayerPosition.midfielder => 2.0,
          _ => 0.0,
        };
        final spaceBonus = pressure.clamp(0, 18) * .55;
        final forwardBonus = forward.clamp(-15, 20) * 1.15;
        final distancePenalty = (distance - 8).abs() * .32;
        final widthPenalty = width > 43 ? (width - 43) * .15 : 0;
        return forwardBonus + spaceBonus + roleBonus - distancePenalty - widthPenalty + random.nextDouble() * 1.5;
      }
      return score(b).compareTo(score(a));
    });
    return pool.first;
  }

  double _nearestOpponentDistance({
    required List<Match2DPlayer> safePlayers,
    required Match2DPlayer player,
  }) {
    var best = double.infinity;
    for (final p in safePlayers) {
      if (!p.active || p.team == player.team) continue;
      best = min(best, _distanceXY(p.x, p.y, player.x, player.y));
    }
    return best;
  }

  void _recordPossessionSecond(Match2DState s) {
    final ownerId = s.ballOwnerId;
    if (ownerId == null) return;
    final owner = s.players.firstWhere((p) => p.id == ownerId && p.active, orElse: () => s.players.firstWhere((p) => p.active, orElse: () => s.players.first));
    final teamKey = owner.team == Match2DTeam.home ? 'home' : 'away';
    if (_possessionSequenceTeam != teamKey) {
      _passingNetwork.possessionStarted(owner.team == Match2DTeam.home);
      _possessionSequenceTeam = teamKey;
    }
    if (owner.team == Match2DTeam.home) s.stats.homePossessionSeconds++;
    else s.stats.awayPossessionSeconds++;
  }

  void _recordEventStats(
    Match2DState s, {
    required Match2DEventType event,
    required Match2DTeam team,
    required bool keyMoment,
  }) {
    final home = team == Match2DTeam.home;
    switch (event) {
      case Match2DEventType.shot:
        home ? s.stats.homeShots++ : s.stats.awayShots++;
        break;
      case Match2DEventType.save:
        home ? s.stats.awayShotsOnTarget++ : s.stats.homeShotsOnTarget++;
        break;
      case Match2DEventType.pass:
      case Match2DEventType.cross:
        if (home) {
          s.stats.homePasses++;
          s.stats.homeCompletedPasses++;
        } else {
          s.stats.awayPasses++;
          s.stats.awayCompletedPasses++;
        }
        break;
      case Match2DEventType.dribble:
        home ? s.stats.homeDribbles++ : s.stats.awayDribbles++;
        break;
      case Match2DEventType.tackle:
      case Match2DEventType.interception:
        home ? s.stats.homeTackles++ : s.stats.awayTackles++;
        break;
      case Match2DEventType.corner:
        home ? s.stats.homeCorners++ : s.stats.awayCorners++;
        break;
      case Match2DEventType.throwIn:
        home ? s.stats.homeThrowIns++ : s.stats.awayThrowIns++;
        break;
      case Match2DEventType.foul:
        home ? s.stats.homeFouls++ : s.stats.awayFouls++;
        break;
      default:
        break;
    }
    if (keyMoment) {
      home ? s.stats.homeKeyMoments++ : s.stats.awayKeyMoments++;
    }
  }

  void _setOwner(
      Match2DState s, Match2DPlayer oldOwner, Match2DPlayer newOwner) {
    oldOwner.hasBall = false;
    newOwner.hasBall = false;
    s.ballOwnerId = oldOwner.id;
    s.ballTargetOwnerId = newOwner.id;
    s.ballTravelProgress = 0.0;
    s.ballBounce = 0;
    s.ballX = oldOwner.x;
    s.ballY = oldOwner.y;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
