import 'player.dart';
import 'match_transition.dart';
import 'player_role.dart';

enum Match2DTeam { home, away }

enum Match2DPhase {
  buildUp,
  progression,
  finalThird,
  shot,
}

enum Match2DEventType {
  pass,
  dribble,
  shot,
  tackle,
  save,
  cross,
  clearance,
  interception,
  goal,
  card,
  injury,
  substitution,
  stoppageTime,
  throwIn,
  corner,
  foul,
  freeKick,
  penalty,
  halftime,
  fulltime,
}

class Match2DPlayer {
  final String id;
  final String name;
  final PlayerPosition position;
  final PlayerRole role;
  final Match2DTeam team;
  final int shirtNumber;
  double x;
  double y;
  double homeX;
  double homeY;
  bool hasBall;
  bool controlledByAI;
  int stamina;
  final int overall;
  final int pace;
  final int shooting;
  final int passing;
  final int dribbling;
  final int defending;
  final int physical;
  bool active;
  bool yellowCard;
  bool redCard;
  bool injured;
  int minutesPlayed;
  /// Runtime movement state; never persisted into career/save data.
  double velocityX;
  double velocityY;
  double facingAngle;
  double staminaAccumulator;

  Match2DPlayer({
    required this.id,
    required this.name,
    required this.position,
    this.role = PlayerRole.boxToBox,
    required this.team,
    required this.x,
    required this.y,
    required this.shirtNumber,
    required this.overall,
    this.pace = 60,
    this.shooting = 60,
    this.passing = 60,
    this.dribbling = 60,
    this.defending = 50,
    this.physical = 60,
    this.active = true,
    this.yellowCard = false,
    this.redCard = false,
    this.injured = false,
    this.minutesPlayed = 0,
    this.velocityX = 0,
    this.velocityY = 0,
    this.facingAngle = 0,
    this.staminaAccumulator = 0,
    double? homeX,
    double? homeY,
    this.hasBall = false,
    this.controlledByAI = true,
    this.stamina = 100,
  })  : homeX = homeX ?? x,
        homeY = homeY ?? y;
}

class Match2DEvent {
  final Match2DEventType type;
  final String playerId;
  final String? secondaryPlayerId;
  final String description;
  final int minute;
  final double x;
  final double y;
  final bool isKeyMoment;
  final String? miniGameType;
  final String? situationId;
  final int situationBeat;
  final bool isChance;

  const Match2DEvent({
    required this.type,
    required this.playerId,
    this.secondaryPlayerId,
    required this.description,
    required this.minute,
    required this.x,
    required this.y,
    this.isKeyMoment = false,
    this.miniGameType,
    this.situationId,
    this.situationBeat = 0,
    this.isChance = false,
  });
}

class Match2DStats {
  int homePossessionSeconds = 0;
  int awayPossessionSeconds = 0;
  int homeShots = 0;
  int awayShots = 0;
  int homeShotsOnTarget = 0;
  int awayShotsOnTarget = 0;
  int homePasses = 0;
  int awayPasses = 0;
  int homeCompletedPasses = 0;
  int awayCompletedPasses = 0;
  int homeDribbles = 0;
  int awayDribbles = 0;
  int homeTackles = 0;
  int awayTackles = 0;
  int homeKeyMoments = 0;
  int awayKeyMoments = 0;
  int homeCorners = 0;
  int awayCorners = 0;
  int homeThrowIns = 0;
  int awayThrowIns = 0;
  int homeFouls = 0;
  int awayFouls = 0;
  int homeYellowCards = 0;
  int awayYellowCards = 0;
  int homeRedCards = 0;
  int awayRedCards = 0;

  double get homePossessionPercent {
    final total = homePossessionSeconds + awayPossessionSeconds;
    return total == 0 ? 50 : homePossessionSeconds * 100 / total;
  }

  double get awayPossessionPercent => 100 - homePossessionPercent;
}

class Match2DState {
  final List<Match2DPlayer> players;
  final List<Match2DPlayer> benchPlayers;
  final List<Match2DEvent> events;
  double ballX;
  double ballY;
  String? ballOwnerId;
  String? ballTargetOwnerId;
  double ballTravelProgress;
  /// Authoritative match-space ball velocity, updated by Match2DEngine.
  /// Used by the renderer for momentum, contact and flight presentation.
  double ballVelocityX;
  double ballVelocityY;
  double ballHeight;
  /// Presentation-ready spin/impact state. Match2DEngine owns these values.
  double ballSpin;
  double ballBounce;
  int minute;
  /// Total minutes elapsed. When minute > 90, the UI renders it as 90+N.
  int stoppageTime;
  int homeGoals;
  int awayGoals;
  bool finished;
  final Match2DStats stats;
  final int? targetHomeGoals;
  final int? targetAwayGoals;
  MatchTransitionPhase homeTransition = MatchTransitionPhase.inPossession;
  MatchTransitionPhase awayTransition = MatchTransitionPhase.inPossession;

  Match2DState({
    required this.players,
    this.benchPlayers = const [],
    this.events = const [],
    this.ballX = 50,
    this.ballY = 50,
    this.ballOwnerId,
    this.ballTargetOwnerId,
    this.ballTravelProgress = 1.0,
    this.ballVelocityX = 0,
    this.ballVelocityY = 0,
    this.ballHeight = 0,
    this.ballSpin = 0,
    this.ballBounce = 0,
    this.minute = 0,
    this.stoppageTime = 0,
    this.homeGoals = 0,
    this.awayGoals = 0,
    this.finished = false,
    Match2DStats? stats,
    this.targetHomeGoals,
    this.targetAwayGoals,
    this.homeTransition = MatchTransitionPhase.inPossession,
    this.awayTransition = MatchTransitionPhase.inPossession,
  }) : stats = stats ?? Match2DStats();
}

Match2DPlayer make2DPlayer(Player p, Match2DTeam team, int index, {String formation = '4-3-3', String managerStyle = 'balanced'}) {
  final localIndex = switch (p.position) {
    PlayerPosition.goalkeeper => 0,
    PlayerPosition.defender => index,
    PlayerPosition.midfielder => index - 5,
    PlayerPosition.winger => index - 8,
    PlayerPosition.striker => 0,
  };
  final role = _roleFor(p.position, localIndex, managerStyle);
  final normalized = _startingPosition(p.position, index, team == Match2DTeam.home, role);
  return Match2DPlayer(
    id: p.id,
    name: p.name,
    position: p.position,
    role: role,
    team: team,
    x: normalized.$1,
    y: normalized.$2,
    homeX: normalized.$1,
    homeY: normalized.$2,
    shirtNumber: p.shirtNumber > 0 ? p.shirtNumber : _fallbackShirtNumber(p.id, index),
    overall: p.overall,
    pace: p.pace,
    shooting: p.shooting,
    passing: p.passing,
    dribbling: p.dribbling,
    defending: p.defending,
    physical: p.physical,
  );
}

int _fallbackShirtNumber(String id, int index) {
  final hash = id.codeUnits.fold<int>(17, (a, b) => a * 31 + b);
  return ((hash.abs() + index) % 99) + 1;
}

PlayerRole _roleFor(PlayerPosition position, int index, String managerStyle) {
  switch (position) {
    case PlayerPosition.goalkeeper:
      return PlayerRole.goalkeeper;
    case PlayerPosition.defender:
      // _pickXI orders the back four left-to-right.
      if (index == 0 || index == 3) {
        return managerStyle == 'high_press' || managerStyle == 'wing_play'
            ? PlayerRole.attackingFullBack
            : PlayerRole.fullBack;
      }
      return index == 1 ? PlayerRole.ballPlayingDefender : PlayerRole.coverDefender;
    case PlayerPosition.midfielder:
      // The three midfielders form a stable triangle.
      if (index == 1) {
        return managerStyle == 'possession' ? PlayerRole.playmaker : PlayerRole.boxToBox;
      }
      if (index == 0 || managerStyle == 'low_block') return PlayerRole.anchor;
      return managerStyle == 'possession' ? PlayerRole.playmaker : PlayerRole.boxToBox;
    case PlayerPosition.winger:
      if (managerStyle == 'wing_play') return PlayerRole.wideWinger;
      if (managerStyle == 'counter') return PlayerRole.insideForward;
      return index.isEven ? PlayerRole.wideWinger : PlayerRole.invertedWinger;
    case PlayerPosition.striker:
      if (managerStyle == 'direct') return PlayerRole.targetForward;
      if (managerStyle == 'high_press') return PlayerRole.pressingForward;
      if (managerStyle == 'possession') return PlayerRole.falseNine;
      return PlayerRole.poacher;
  }
}

(double, double) _startingPosition(
    PlayerPosition position, int index, bool home, PlayerRole role) {
  switch (position) {
    case PlayerPosition.goalkeeper:
      return (home ? 8 : 92, 50);
    case PlayerPosition.defender:
      final y = switch (index) {
        0 => 14.0,
        1 => 39.0,
        2 => 61.0,
        _ => 86.0,
      };
      final x = switch (role) {
        PlayerRole.attackingFullBack => 27.0,
        PlayerRole.fullBack => 24.0,
        _ => 25.0,
      };
      return (home ? x : 100 - x, y);
    case PlayerPosition.midfielder:
      final y = switch (index) {
        0 => 30.0,
        1 => 50.0,
        _ => 70.0,
      };
      final depth = role == PlayerRole.anchor ? 38.0 : role == PlayerRole.playmaker ? 45.0 : 43.0;
      return (home ? depth : 100 - depth, y);
    case PlayerPosition.winger:
      final y = index.isEven ? 10.0 : 90.0;
      final depth = role == PlayerRole.insideForward ? 61.0 : 58.0;
      return (home ? depth : 100 - depth, y);
    case PlayerPosition.striker:
      final depth = role == PlayerRole.falseNine ? 62.0 : 69.0;
      return (home ? depth : 100 - depth, 50);
  }
}
