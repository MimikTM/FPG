import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/match_2d.dart';
import '../models/player.dart';
import 'broadcast_camera_director.dart';
import 'match_presentation_director.dart';
import 'match_replay_director.dart';
import 'match_referee_director.dart';
import 'stadium_atmosphere_director.dart';
import 'match_cinematic_director.dart';

/// Real-time animated pitch renderer, built on Flame.
///
/// Presentation only: Match2DEngine remains the source of truth. This layer
/// turns the coarse simulation positions into a more game-like presentation:
/// smooth acceleration/deceleration, facing direction, a lightweight player
/// animation state machine and contextual action animations.
class PitchGame extends FlameGame {
  PitchGame({required this.getState, required this.kitColorFor, MatchPresentationDirector? presentationDirector})
      : _presentationDirector = presentationDirector ?? MatchPresentationDirector();

  final Match2DState? Function() getState;
  final Color Function(Match2DTeam team) kitColorFor;

  final Map<String, _PlayerDot> _dots = {};
  late final _BallDot _ball = _BallDot(trail: _ballTrail);
  final _PitchBackground _background = _PitchBackground();
  final List<Vector2> _ballTrail = [];
  int _lastEventCount = 0;
  String? _lastBallOwnerId;
  String? _lastBallTargetOwnerId;
  double _contactPulse = 0;
  double _previousBallX = 50;
  double _previousBallY = 50;
  double _ballSpeedPx = 0;
  Vector2 _ballVelocity = Vector2.zero();
  double _ballContactFlash = 0;
  double _matchPulse = 0;
  double _shotPresentationPulse = 0;
  Vector2? _lastShotPosition;
  final Set<String> _activePlayerContacts = <String>{};
  final BroadcastCameraDirector _cameraDirector = BroadcastCameraDirector();
  final MatchPresentationDirector _presentationDirector;
  final MatchReplayDirector _replayDirector = MatchReplayDirector();
  final MatchRefereeDirector _refereeDirector = MatchRefereeDirector();
  final StadiumAtmosphereDirector _atmosphereDirector = StadiumAtmosphereDirector();
  late final StadiumAtmosphereComponent _atmosphere = StadiumAtmosphereComponent(_atmosphereDirector);
  late final RefereeComponent _referee = RefereeComponent(_refereeDirector);
  final MatchCinematicDirector _cinematicDirector = MatchCinematicDirector();
  late final CinematicFrame _cinematicFrame = CinematicFrame(_cinematicDirector);
  Vector2 _cameraTarget = Vector2.zero();
  double _cameraZoom = 1.0;
  double _goalSequenceTimer = 0;
  double _substitutionSequenceTimer = 0;
  String? _subInId;
  String? _subOutId;
  String? _subInName;
  String? _subOutName;
  String? _goalScorerId;
  Vector2? _goalPosition;

  MatchPresentationDirector get presentationDirector => _presentationDirector;
  MatchReplayDirector get replayDirector => _replayDirector;
  MatchRefereeDirector get refereeDirector => _refereeDirector;
  StadiumAtmosphereDirector get atmosphereDirector => _atmosphereDirector;
  MatchCinematicDirector get cinematicDirector => _cinematicDirector;

  @override
  Color backgroundColor() => const Color(0xFF1D5C34);

  @override
  Future<void> onLoad() async {
    add(_background);
    add(_atmosphere);
    add(_ball);
    _cameraTarget = size / 2;
    _cameraDirector.reset(_cameraTarget);
    add(_ReplayBanner(_replayDirector)..position = size / 2);
    add(_referee);
    add(_cinematicFrame);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _background.size = size * 1.35;
    _background.position = -size * .175;
    for (final child in children) {
      if (child is _ReplayBanner) child.position = size / 2;
    }
    if (_cameraTarget == Vector2.zero()) {
      _cameraTarget = size / 2;
      _cameraDirector.reset(_cameraTarget);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final state = getState();
    if (state == null || size.x <= 0 || size.y <= 0) return;

    _replayDirector.record(state, dt);

    final seenIds = <String>{};
    for (final p in state.players) {
      if (!p.active) continue;
      seenIds.add(p.id);
      var dot = _dots[p.id];
      if (dot == null) {
        dot = _PlayerDot(color: kitColorFor(p.team))
          ..position = Vector2(p.x / 100 * size.x, p.y / 100 * size.y);
        _dots[p.id] = dot;
        add(dot);
      }
      dot.targetX = p.x / 100 * size.x;
      dot.targetY = p.y / 100 * size.y;
      dot.shirtNumber = p.shirtNumber;
      dot.isGoalkeeper = p.position == PlayerPosition.goalkeeper;
      dot.hasBall = p.hasBall;
      dot.yellowCard = p.yellowCard;
      dot.redCard = p.redCard;
      dot.injured = p.injured;
    }

    final stale = _dots.keys.where((id) => !seenIds.contains(id)).toList();
    for (final id in stale) {
      _dots[id]?.removeFromParent();
      _dots.remove(id);
    }

    // Feed newly-created simulation events into the presentation state
    // machine. The simulation stays untouched; this is purely visual.
    // A new match can reuse the same PitchGame instance. Never replay stale
    // events when the authoritative event list is reset.
    if (state.events.length < _lastEventCount) {
      _lastEventCount = 0;
      _lastBallOwnerId = null;
      _lastBallTargetOwnerId = null;
      _ballTrail.clear();
      _activePlayerContacts.clear();
      _refereeDirector.reset(size / 2);
      _atmosphereDirector.reset();
    }
    if (state.events.length > _lastEventCount) {
      for (var i = _lastEventCount; i < state.events.length; i++) {
        final event = state.events[i];
        _presentationDirector.onEvent(event);
        _atmosphereDirector.onEvent(event, state);
        final eventPosition = Vector2(event.x / 100 * size.x, event.y / 100 * size.y);
        _refereeDirector.onEvent(event, eventPosition, {
          for (final p in state.players)
            if (p.active) p.id: Vector2(p.x / 100 * size.x, p.y / 100 * size.y),
        });
        final player = _dots[event.playerId];
        final isPass = event.type == Match2DEventType.pass || event.type == Match2DEventType.cross;
        if (isPass && player != null) {
          final secondary = event.secondaryPlayerId == null ? null : _dots[event.secondaryPlayerId!];
          final targetDirection = secondary == null
              ? Vector2(cos(player.facingAngle), sin(player.facingAngle))
              : secondary.position - player.position;
          player.triggerPass(targetDirection, isCross: event.type == Match2DEventType.cross);
          add(_PassRelease(position: player.position.clone()));
        } else {
          if (event.type == Match2DEventType.save && player != null && player.isGoalkeeper) {
            final eventPosition = Vector2(event.x / 100 * size.x, event.y / 100 * size.y);
            player.triggerSave(eventPosition - player.position);
          } else {
            player?.triggerAction(event.type);
          }
        }
        if (event.secondaryPlayerId != null) {
          final secondary = _dots[event.secondaryPlayerId!];
          if (secondary != null) {
            secondary.triggerAction(event.type, asReceiver: isPass);
          }
        }
        if (event.type == Match2DEventType.substitution) {
          _startSubstitutionSequence(event, state);
        }
        final isReplayMoment = event.isKeyMoment ||
            event.type == Match2DEventType.goal ||
            event.type == Match2DEventType.shot ||
            event.type == Match2DEventType.save;
        if (isReplayMoment) {
          _replayDirector.triggerReplay(event.type);
        }
        if (event.type == Match2DEventType.goal || event.type == Match2DEventType.shot || event.type == Match2DEventType.save) {
          _matchPulse = event.type == Match2DEventType.goal ? 0.34 : 0.22;
          _cameraDirector.onEvent(event);
          add(_ActionRing(position: eventPosition, kind: event.type));
          if (event.type == Match2DEventType.goal) {
            _goalScorerId = event.playerId;
            _goalPosition = eventPosition;
            _goalSequenceTimer = 2.8;
            _cameraDirector.onEvent(event);
            add(_GoalSequenceFlash(position: eventPosition));
          }
          if (event.type == Match2DEventType.shot || event.type == Match2DEventType.goal) {
            _shotPresentationPulse = event.type == Match2DEventType.goal ? 0.62 : 0.48;
            _lastShotPosition = eventPosition;
            _dots[event.playerId]?.prepareShot();
            add(_ShotImpact(position: eventPosition));
          }
        }
      }
      _lastEventCount = state.events.length;
    }

    _presentationDirector.update(dt);
    _replayDirector.update(dt);
    _atmosphereDirector.update(dt, state);
    _atmosphere.size = size;
    _matchPulse = max(0, _matchPulse - dt);
    _contactPulse = max(0, _contactPulse - dt);
    _shotPresentationPulse = max(0, _shotPresentationPulse - dt);
    _goalSequenceTimer = max(0, _goalSequenceTimer - dt);
    _substitutionSequenceTimer = max(0, _substitutionSequenceTimer - dt);

    // Compute the current ball presentation position before camera logic so
    // the camera and renderer consume the same frame-space coordinates.
    final ballXpx = state.ballX / 100 * size.x;
    final ballYpx = state.ballY / 100 * size.y;

    _refereeDirector.update(dt, Vector2(ballXpx, ballYpx), size);
    _cinematicDirector.update(dt, _presentationDirector, state, size);

    // Broadcast camera director: ordinary play follows the ball; key moments
    // briefly reframe the relevant player/event. This is presentation-only.
    final defaultTarget = Vector2(ballXpx, ballYpx);
    final playerTargets = <String, Vector2>{
      for (final p in state.players)
        if (p.active) p.id: Vector2(p.x / 100 * size.x, p.y / 100 * size.y),
    };
    _cameraDirector.update(dt, defaultTarget, playerTargets);
    _cameraTarget = _cameraDirector.target;
    _cameraZoom = _cameraDirector.zoom;
    if (_cinematicDirector.hasCinematicFrame) {
      _cameraTarget += _cinematicDirector.cameraOffset;
      _cameraZoom *= _cinematicDirector.cameraZoom;
    }

    // During replay the renderer consumes historical samples. The simulation
    // continues normally in the background and remains authoritative.
    final replay = _replayDirector.current;
    if (replay != null) {
      for (final entry in replay.players.entries) {
        final dot = _dots[entry.key];
        final rp = entry.value;
        if (dot != null) {
          dot.targetX = rp.x / 100 * size.x;
          dot.targetY = rp.y / 100 * size.y;
          dot.hasBall = rp.hasBall;
        }
      }
      _ball.targetX = replay.ballX / 100 * size.x;
      _ball.targetY = replay.ballY / 100 * size.y;
      _ball.height = replay.ballHeight * size.y / 100;
      _cameraTarget = Vector2(
        replay.ballX / 100 * size.x,
        replay.ballY / 100 * size.y,
      );
      _cameraZoom = 1.10;
    }
    camera.viewfinder.zoom = _cameraZoom;
    camera.viewfinder.position = _cameraTarget;

    // Presentation-side possession/contact detector. The simulation remains
    // authoritative; this only turns its ballTargetOwnerId -> ballOwnerId
    // transition into a readable first-touch animation and a tiny impact FX.
    final ownerId = state.ballOwnerId;
    final targetId = state.ballTargetOwnerId;
    final dxPx = ballXpx - _previousBallX;
    final dyPx = ballYpx - _previousBallY;
    final rawBallVelocity = Vector2(dxPx, dyPx) / max(dt, 0.0001);
    _ballSpeedPx = rawBallVelocity.length;
    // Presentation-side ball physics: smooth the authoritative simulation
    // velocity so visual contact/release has momentum without changing the
    // simulation's source-of-truth coordinates.
    final velocityBlend = min(1.0, dt * 18.0);
    _ballVelocity += (rawBallVelocity - _ballVelocity) * velocityBlend;
    _ballContactFlash = max(0, _ballContactFlash - dt);

    if (targetId != null && targetId != _lastBallTargetOwnerId) {
      _dots[targetId]?.prepareReceive();
      _lastBallTargetOwnerId = targetId;
    }

    final completedPass = targetId == null &&
        _lastBallTargetOwnerId != null &&
        ownerId != null &&
        ownerId == _lastBallTargetOwnerId;
    if (completedPass) {
      final receiver = _dots[ownerId];
      receiver?.completeFirstTouch(_ballVelocity);
      _ballContactFlash = .20;
      add(_ContactBurst(position: Vector2(ballXpx, ballYpx)));
      add(_BallContactMark(position: Vector2(ballXpx, ballYpx)));
      _contactPulse = .18;
      _lastBallTargetOwnerId = null;
    }
    if (ownerId != _lastBallOwnerId) {
      if (ownerId != null) {
        _dots[ownerId]?.setPossessionPulse();
        // A possession change while the ball was travelling is a genuine
        // contact/interception. Keep this presentation-only: the engine has
        // already decided the authoritative owner.
        if (_lastBallOwnerId != null && targetId != null) {
          final contact = _dots[ownerId];
          contact?.triggerBallContact(_ballVelocity);
          add(_ContactBurst(position: Vector2(ballXpx, ballYpx)));
          _contactPulse = .22;
        }
      }
      _lastBallOwnerId = ownerId;
    }

    // Presentation-only player/player contact pass. Match2DEngine remains
    // authoritative; this layer only adds readable body-to-body impact when
    // two rendered players actually converge.
    final activePlayers = _dots.values.where((d) => d.parent != null).toList();
    final currentContacts = <String>{};
    for (var i = 0; i < activePlayers.length; i++) {
      for (var j = i + 1; j < activePlayers.length; j++) {
        final a = activePlayers[i];
        final b = activePlayers[j];
        final distance = a.position.distanceTo(b.position);
        if (distance > 15) continue;
        final ids = [identityHashCode(a), identityHashCode(b)]..sort();
        final key = '${ids[0]}:${ids[1]}';
        currentContacts.add(key);
        if (!_activePlayerContacts.contains(key)) {
          a.triggerContact(b.position - a.position);
          b.triggerContact(a.position - b.position);
          final midpoint = (a.position + b.position) / 2;
          add(_PlayerContactBurst(position: midpoint));
        }
      }
    }
    _activePlayerContacts
      ..clear()
      ..addAll(currentContacts);

    _previousBallX = ballXpx;
    _previousBallY = ballYpx;

    _ball.targetX = ballXpx;
    _ball.targetY = ballYpx;
    _ball.shotPulse = _shotPresentationPulse;
    _ball.velocity = Vector2(state.ballVelocityX * size.x / 100, state.ballVelocityY * size.y / 100);
    _ball.height = state.ballHeight * size.y / 100;
    _ball.spinRate = state.ballSpin;
    _ball.bounce = state.ballBounce;
    _ball.contactFlash = _ballContactFlash;
    _ball.isTravelling = state.ballTravelProgress < 1.0 || state.ballOwnerId == null;
    if (_ballTrail.length > 10) _ballTrail.removeAt(0);
    if (_ballTrail.isEmpty || _ballTrail.last.distanceTo(_ball.position) > 4) {
      _ballTrail.add(_ball.position.clone());
    }
  }

  void _startSubstitutionSequence(Match2DEvent event, Match2DState state) {
    _subInId = event.playerId;
    _subOutId = event.secondaryPlayerId;
    final incoming = state.players.where((p) => p.id == event.playerId).firstOrNull;
    final outgoing = state.players.where((p) => p.id == event.secondaryPlayerId).firstOrNull;
    _subInName = incoming?.name ?? 'IN';
    _subOutName = outgoing?.name ?? 'OUT';
    _substitutionSequenceTimer = 3.2;
    // Camera direction is driven by the substitution event itself.
    final pos = Vector2(event.x / 100 * size.x, event.y / 100 * size.y);
    add(_SubstitutionSequenceBanner(
      position: pos,
      incomingName: _subInName!,
      outgoingName: _subOutName!,
      incomingNumber: incoming?.shirtNumber,
      outgoingNumber: outgoing?.shirtNumber,
    ));
    _dots[event.playerId]?.triggerSubstitutionIn();
    if (event.secondaryPlayerId != null) {
      _dots[event.secondaryPlayerId!]?.triggerSubstitutionOut();
    }
    add(_SubstitutionTouchlineBurst(position: pos));
  }

  /// Called from MatchScreen when a goal event fires. Starts a presentation
  /// sequence without changing the authoritative match state.
  void celebrateGoal() {
    if (size.x <= 0 || size.y <= 0) return;
    final position = _ball.position.clone();
    _goalPosition = position;
    _goalSequenceTimer = 2.8;
    // Goal camera is driven by the goal event itself.
    add(_GoalBurst(position: position));
    add(_GoalSequenceFlash(position: position));
    final scorerName = _goalScorerId == null ? null : _dots[_goalScorerId]?.shirtNumber.toString();
    add(_GoalSequenceBanner(position: position, scorerLabel: scorerName));
    final scorer = _goalScorerId == null ? null : _dots[_goalScorerId];
    scorer?.triggerAction(Match2DEventType.goal);
    for (final dot in _dots.values) {
      if (dot != scorer) dot.triggerGoalReaction(scorer?.position ?? position);
    }
  }
}

class _PitchBackground extends PositionComponent {
  @override
  void render(Canvas canvas) {
    final w = size.x, h = size.y;
    if (w <= 0 || h <= 0) return;

    const light = Color(0xFF2E8B4E);
    const dark = Color(0xFF267A44);
    const stripes = 10;
    final stripeWidth = w / stripes;
    for (var i = 0; i < stripes; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * stripeWidth, 0, stripeWidth, h),
        Paint()..color = i.isEven ? light : dark,
      );
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: .85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawRect(Rect.fromLTWH(1, 1, w - 2, h - 2), line);
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), line);
    canvas.drawCircle(Offset(w / 2, h / 2), h * .14, line);
    canvas.drawCircle(Offset(w / 2, h / 2), 2, Paint()..color = Colors.white);

    for (final left in [true, false]) {
      final penW = w * .16;
      final penH = h * .62;
      final sixW = w * .06;
      final sixH = h * .30;
      final x = left ? 0.0 : w - penW;
      canvas.drawRect(Rect.fromLTWH(x, (h - penH) / 2, penW, penH), line);
      final sixX = left ? 0.0 : w - sixW;
      canvas.drawRect(Rect.fromLTWH(sixX, (h - sixH) / 2, sixW, sixH), line);
      final spotX = left ? penW * .62 : w - penW * .62;
      canvas.drawCircle(Offset(spotX, h / 2), 1.8, Paint()..color = Colors.white);
      final arcRect = Rect.fromCircle(center: Offset(spotX, h / 2), radius: h * .14);
      canvas.drawArc(arcRect, left ? -0.9 : pi - 0.9, 1.8, false, line);
      final goalH = h * .14;
      final goalX = left ? -3.0 : w - 2.0;
      canvas.drawRect(Rect.fromLTWH(goalX, (h - goalH) / 2, 5, goalH), line);
    }

    for (final corner in [Offset(0, 0), Offset(w, 0), Offset(0, h), Offset(w, h)]) {
      canvas.drawArc(Rect.fromCircle(center: corner, radius: 5), 0, 2 * pi, false, line);
    }
  }
}

enum _PlayerAnimState {
  idle,
  jog,
  sprint,
  receive,
  pass,
  shoot,
  dribble,
  tackle,
  save,
  celebrate,
  injured,
  goalReaction,
  substitutionIn,
  substitutionOut,
}

/// Procedural player presentation. It intentionally uses no external sprite
/// sheet yet, so the new animation architecture can ship before final art.
/// Replacing the painter with sprite assets later does not require changing
/// Match2DEngine or MatchScreen.
class _PlayerDot extends PositionComponent {
  _PlayerDot({required this.color}) : super(anchor: Anchor.center);

  final Color color;
  double targetX = 0;
  double targetY = 0;
  int shirtNumber = 0;
  bool isGoalkeeper = false;
  bool hasBall = false;
  bool yellowCard = false;
  bool redCard = false;
  bool injured = false;

  double _vx = 0;
  double _vy = 0;
  double _speed = 0;
  double _facing = 0;
  double _animTime = 0;
  double _actionTime = 0;
  double _actionDuration = 0.65;
  _PlayerAnimState _state = _PlayerAnimState.idle;
  double _contactFlash = 0;
  double _lean = 0;

  static const double _maxFollowSpeed = 520.0;
  static const double _acceleration = 1900.0;
  static const double _deceleration = 2400.0;

  double _receiveBlend = 0;
  double _possessionPulse = 0;
  Vector2 _contactDirection = Vector2.zero();
  Vector2 _firstTouchDirection = Vector2.zero();
  double _contactStrength = 0;
  double _firstTouchStrength = 0;
  double _receivePreparation = 0;
  double _receiveContact = 0;
  double _receiveRelease = 0;
  double _receiveTurn = 0;
  bool _receiveProtectsBall = false;

  double _substitutionSlide = 0;

  // Goalkeeper 2.0 presentation: read the shot direction, set the body,
  // commit to a dive, reach through the save contact beat and recover.
  double _saveAnticipation = 0;
  double _saveDive = 0;
  double _saveReach = 0;
  double _saveRecovery = 0;
  Vector2 _saveDirection = Vector2.zero();

  // Dribbling 2.0 presentation: alternating touches, body feints and
  // acceleration/deceleration cues. The authoritative ball position remains
  // owned by Match2DEngine; these values only drive player animation.
  double _dribblePhase = 0;
  double _dribbleBlend = 0;
  double _dribbleFeint = 0;
  double _dribbleTouch = 0;
  Vector2 _dribbleDirection = Vector2.zero();

  void prepareDribble(Vector2 direction) {
    if (injured) return;
    _state = _PlayerAnimState.dribble;
    _actionTime = 0;
    _actionDuration = .46;
    _dribbleBlend = 1;
    if (direction.length2 > .01) {
      _dribbleDirection = direction.normalized();
      _facing = atan2(_dribbleDirection.y, _dribbleDirection.x);
    }
  }

  void triggerDribbleTouch(Vector2 direction) {
    if (injured) return;
    _state = _PlayerAnimState.dribble;
    _dribbleBlend = 1;
    _dribbleTouch = 1;
    if (direction.length2 > .01) {
      _dribbleDirection = direction.normalized();
    }
  }

  void prepareReceive() {
    if (injured) return;
    _receiveBlend = 1;
    _state = _PlayerAnimState.receive;
    _actionTime = 0;
    _actionDuration = .62;
    _receivePreparation = 0;
    _receiveContact = 0;
    _receiveRelease = 0;
    _receiveTurn = 0;
    _receiveProtectsBall = false;
  }

  void completeFirstTouch(Vector2 incomingVelocity) {
    if (injured) return;
    _receiveBlend = 1;
    _state = hasBall ? _PlayerAnimState.dribble : _PlayerAnimState.receive;
    _actionTime = 0;
    _actionDuration = .62;
    _contactFlash = .2;

    // Presentation-only directional first touch. We use the incoming
    // authoritative ball velocity to choose the cushioning direction.
    // This does not alter Match2DEngine coordinates or possession logic.
    if (incomingVelocity.length2 > 4) {
      _firstTouchDirection = incomingVelocity.normalized();
    } else {
      _firstTouchDirection = Vector2(cos(_facing), sin(_facing));
    }
    _firstTouchStrength = 1;
    _receivePreparation = .75;
    _receiveContact = 1;
    _receiveRelease = 0;
    _receiveTurn = 0;
    _receiveProtectsBall = true;
  }

  void triggerSave(Vector2 direction) {
    if (injured) return;
    _state = _PlayerAnimState.save;
    _actionTime = 0;
    _actionDuration = 1.02;
    _contactFlash = .24;
    if (direction.length2 > .01) {
      _saveDirection = direction.normalized();
      _facing = atan2(_saveDirection.y, _saveDirection.x);
    } else {
      _saveDirection = Vector2(cos(_facing), sin(_facing));
    }
    _saveAnticipation = 0;
    _saveDive = 0;
    _saveReach = 0;
    _saveRecovery = 0;
  }

  void setPossessionPulse() {
    _possessionPulse = .22;
  }

  void triggerBallContact(Vector2 incomingVelocity) {
    if (injured) return;
    _contactFlash = .22;
    _contactStrength = .9;
    if (incomingVelocity.length2 > 1) {
      _contactDirection = incomingVelocity.normalized();
    }
    _state = _PlayerAnimState.receive;
    _actionTime = 0;
    _actionDuration = .28;
  }

  void triggerContact(Vector2 direction) {
    if (injured) return;
    if (direction.length2 > 0) {
      _contactDirection = direction.normalized();
    }
    _contactStrength = 1;
    _contactFlash = .16;
    // Do not overwrite a stronger gameplay action such as a shot or save.
    if (_state == _PlayerAnimState.idle ||
        _state == _PlayerAnimState.jog ||
        _state == _PlayerAnimState.sprint ||
        _state == _PlayerAnimState.dribble) {
      _state = _PlayerAnimState.tackle;
      _actionTime = 0;
      // Tackle 2.0 is deliberately longer than a single impact frame:
      // approach -> plant -> challenge -> contact -> recovery.
      _actionDuration = .58;
    }
  }

  double get facingAngle => _facing;

  void triggerPass(Vector2 targetDirection, {bool isCross = false}) {
    if (injured) return;
    if (targetDirection.length2 > 0.01) {
      _contactDirection = targetDirection.normalized();
      _facing = atan2(_contactDirection.y, _contactDirection.x);
    }
    _state = _PlayerAnimState.pass;
    _actionTime = 0;
    _actionDuration = isCross ? .72 : .62;
    _contactStrength = isCross ? .72 : .58;
    _contactFlash = .12;
  }

  void prepareShot() {
    if (injured) return;
    _state = _PlayerAnimState.shoot;
    _actionTime = 0;
    _actionDuration = .92;
    _contactFlash = .18;
    _contactDirection = Vector2(cos(_facing), sin(_facing));
  }

  void triggerAction(Match2DEventType type, {bool asReceiver = false}) {
    final next = asReceiver
        ? _PlayerAnimState.receive
        : switch (type) {
      Match2DEventType.pass || Match2DEventType.cross => _PlayerAnimState.pass,
      Match2DEventType.shot => _PlayerAnimState.shoot,
      Match2DEventType.tackle || Match2DEventType.interception => _PlayerAnimState.tackle,
      Match2DEventType.save => _PlayerAnimState.save,
      Match2DEventType.dribble => _PlayerAnimState.dribble,
      Match2DEventType.injury => _PlayerAnimState.injured,
      Match2DEventType.goal => _PlayerAnimState.goalReaction,
      _ => null,
    };
    if (next == null) return;
    _state = next;
    _actionTime = 0;
    _actionDuration = switch (next) {
      _PlayerAnimState.pass => 0.52,
      _PlayerAnimState.shoot => 0.78,
      _PlayerAnimState.tackle => 0.72,
      _PlayerAnimState.save => 0.9,
      _PlayerAnimState.dribble => 0.42,
      _PlayerAnimState.receive => 0.48,
      _PlayerAnimState.injured => 1.2,
      _PlayerAnimState.goalReaction => .9,
      _ => 0.65,
    };
    _contactFlash = 0.16;
    if (next == _PlayerAnimState.dribble) {
      _dribbleBlend = 1;
      _dribblePhase += .4;
      _dribbleDirection = Vector2(cos(_facing), sin(_facing));
    }
  }

  void triggerSubstitutionIn() {
    if (injured) return;
    _state = _PlayerAnimState.substitutionIn;
    _actionTime = 0;
    _actionDuration = 1.05;
    _substitutionSlide = 1;
  }

  void triggerSubstitutionOut() {
    _state = _PlayerAnimState.substitutionOut;
    _actionTime = 0;
    _actionDuration = 1.05;
    _substitutionSlide = 1;
  }

  void triggerGoalReaction(Vector2 scorerPosition) {
    if (injured) return;
    _state = _PlayerAnimState.goalReaction;
    _actionTime = 0;
    _actionDuration = .9;
    final direction = scorerPosition - position;
    if (direction.length2 > .01) {
      _facing = atan2(direction.y, direction.x);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt <= 0) return;

    final target = Vector2(targetX, targetY);
    final delta = target - position;
    final dist = delta.length;
    final desiredSpeed = min(_maxFollowSpeed, dist * 8.5);

    // Acceleration/deceleration gives the existing simulation positions
    // believable body momentum instead of simply lerping a dot.
    if (desiredSpeed > _speed) {
      _speed = min(desiredSpeed, _speed + _acceleration * dt);
    } else {
      _speed = max(desiredSpeed, _speed - _deceleration * dt);
    }

    if (dist > 0.05 && _speed > 0.01) {
      final direction = delta.normalized();
      final desiredVx = direction.x * _speed;
      final desiredVy = direction.y * _speed;
      final blend = min(1.0, 12.0 * dt);
      _vx += (desiredVx - _vx) * blend;
      _vy += (desiredVy - _vy) * blend;
      position += Vector2(_vx, _vy) * dt;
      if (_vx.abs() + _vy.abs() > 2) {
        _facing = atan2(_vy, _vx);
      }
    } else {
      _vx *= max(0.0, 1 - 10 * dt);
      _vy *= max(0.0, 1 - 10 * dt);
      position += Vector2(_vx, _vy) * dt;
    }

    _animTime += dt;
    _actionTime += dt;

    if (hasBall && _state != _PlayerAnimState.tackle &&
        _state != _PlayerAnimState.shoot &&
        _state != _PlayerAnimState.pass &&
        _state != _PlayerAnimState.receive) {
      _state = _PlayerAnimState.dribble;
      _dribbleBlend = min(1.0, _dribbleBlend + dt * 5.0);
    }
    if (_state == _PlayerAnimState.dribble && hasBall) {
      _dribblePhase += dt * (5.5 + intensitySafe(_speed) * 8.5);
      _dribbleTouch = (sin(_dribblePhase) * .5 + .5);
      // Feint peaks between touches and becomes smaller at sprint speed.
      _dribbleFeint = sin(_dribblePhase * .5) * (1.0 - intensitySafe(_speed) * .35);
      if (_dribbleDirection.length2 < .01) {
        _dribbleDirection = Vector2(cos(_facing), sin(_facing));
      }
    } else {
      _dribbleBlend = max(0, _dribbleBlend - dt * 4.0);
      _dribbleTouch = max(0, _dribbleTouch - dt * 5.0);
      _dribbleFeint *= max(0, 1 - dt * 5);
    }

    _contactFlash = max(0, _contactFlash - dt);
    _receiveBlend = max(0, _receiveBlend - dt * 3.2);
    _possessionPulse = max(0, _possessionPulse - dt);
    _contactStrength = max(0, _contactStrength - dt * 3.8);
    _firstTouchStrength = max(0, _firstTouchStrength - dt * 2.8);
    _receivePreparation = max(0, _receivePreparation - dt * 3.0);
    _receiveContact = max(0, _receiveContact - dt * 3.6);
    _receiveRelease = min(1, _receiveRelease + dt * 2.2);
    _receiveTurn = min(1, _receiveTurn + dt * 1.7);
    _substitutionSlide = max(0, _substitutionSlide - dt * 1.25);
    if (_state == _PlayerAnimState.save) {
      final t = (_actionTime / _actionDuration).clamp(0.0, 1.0);
      _saveAnticipation = Curves.easeOut.transform((t / .24).clamp(0.0, 1.0));
      _saveDive = Curves.easeInOut.transform(((t - .18) / .28).clamp(0.0, 1.0));
      _saveReach = Curves.easeOut.transform(((t - .32) / .22).clamp(0.0, 1.0));
      _saveRecovery = Curves.easeInOut.transform(((t - .58) / .44).clamp(0.0, 1.0));
    } else {
      _saveAnticipation = max(0, _saveAnticipation - dt * 5);
      _saveDive = max(0, _saveDive - dt * 5);
      _saveReach = max(0, _saveReach - dt * 5);
      _saveRecovery = min(1, _saveRecovery + dt * 4);
    }
    final velocityLean = (_vx * cos(_facing) + _vy * sin(_facing)) / _maxFollowSpeed;
    _lean += (velocityLean.clamp(-1.0, 1.0) - _lean) * min(1.0, dt * 9);
    if (_actionTime > _actionDuration && _state != _PlayerAnimState.injured) {
      _state = _deriveLocomotionState();
    } else if (_state == _PlayerAnimState.idle || _state == _PlayerAnimState.jog || _state == _PlayerAnimState.sprint) {
      _state = _deriveLocomotionState();
    }
  }

  double intensitySafe(double speed) =>
      (speed / _maxFollowSpeed).clamp(0.0, 1.0);

  _PlayerAnimState _deriveLocomotionState() {
    if (injured) return _PlayerAnimState.injured;
    if (_speed < 12) return hasBall ? _PlayerAnimState.receive : _PlayerAnimState.idle;
    if (hasBall) return _PlayerAnimState.dribble;
    return _speed > 290 ? _PlayerAnimState.sprint : _PlayerAnimState.jog;
  }

  @override
  void render(Canvas canvas) {
    final intensity = (_speed / _maxFollowSpeed).clamp(0.0, 1.0);
    final phase = _animTime * (4.5 + intensity * 8.0);
    final stride = sin(phase) * (1.0 + intensity * 2.7);
    final bob = sin(phase * 2) * (0.25 + intensity * 0.55);
    final actionT = (_actionTime / _actionDuration).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(actionT);
    final actionStrength = sin(actionT * pi);
    final goalReact = _state == _PlayerAnimState.goalReaction
        ? sin((actionT.clamp(0.0, 1.0)) * pi)
        : 0.0;
    final injuredLean = injured ? 1.15 * min(1.0, _actionTime / 0.8) : 0.0;
    final goalCelebrationLift = goalReact * 3.0;
    final subInT = _state == _PlayerAnimState.substitutionIn ? Curves.easeOutCubic.transform((actionT / .7).clamp(0.0, 1.0)) : 0.0;
    final subOutT = _state == _PlayerAnimState.substitutionOut ? Curves.easeInCubic.transform((actionT / .9).clamp(0.0, 1.0)) : 0.0;
    final receiveT = (_actionTime / _actionDuration).clamp(0.0, 1.0);
    final receivePrep = Curves.easeOut.transform((receiveT / .28).clamp(0.0, 1.0));
    final receiveContact = sin((((receiveT - .24) / .18).clamp(0.0, 1.0)) * pi);
    final receiveRelease = Curves.easeInOut.transform(((receiveT - .38) / .30).clamp(0.0, 1.0));
    final receiveTurn = Curves.easeOut.transform(((receiveT - .46) / .34).clamp(0.0, 1.0));
    final touchCrouch = _receiveBlend * (.75 + receivePrep * .45) - receiveRelease * .28;
    final touchDirX = _firstTouchDirection.x;
    final touchDirY = _firstTouchDirection.y;

    // Dribbling 2.0: alternating touches, subtle feint and body lead.
    final dribbleIntensity = _dribbleBlend * (hasBall ? 1.0 : .55);
    final dribbleSide = sin(_dribblePhase) * (1.4 + intensity * 1.8) * dribbleIntensity;
    final dribbleTouchBeat = sin(_dribblePhase) * dribbleIntensity;
    final dribbleFeintX = cos(_facing + pi / 2) * _dribbleFeint * 2.8 * dribbleIntensity;
    final dribbleFeintY = sin(_facing + pi / 2) * _dribbleFeint * 2.8 * dribbleIntensity;

    final shotAnticipation = _state == _PlayerAnimState.shoot
        ? Curves.easeInOut.transform((actionT / .34).clamp(0.0, 1.0))
        : 0.0;
    final shotContact = _state == _PlayerAnimState.shoot
        ? ((actionT - .34) / .12).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final shotRecovery = _state == _PlayerAnimState.shoot
        ? ((actionT - .76) / .24).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final shotRelease = _state == _PlayerAnimState.shoot
        ? ((actionT - .46) / .30).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final shootKick = _state == _PlayerAnimState.shoot
        ? (-8.0 * shotAnticipation) +
            (15.0 * Curves.easeOut.transform(shotRelease)) -
            (3.0 * shotRecovery)
        : 0.0;
    final tackleApproach = _state == _PlayerAnimState.tackle
        ? Curves.easeOut.transform((actionT / .22).clamp(0.0, 1.0).toDouble())
        : 0.0;
    final tackleContact = _state == _PlayerAnimState.tackle
        ? sin((((actionT - .30) / .12).clamp(0.0, 1.0).toDouble()) * pi)
        : 0.0;
    final tacklePlant = _state == _PlayerAnimState.tackle
        ? Curves.easeOut.transform((actionT / .18).clamp(0.0, 1.0).toDouble())
        : 0.0;
    final tackleRecovery = _state == _PlayerAnimState.tackle
        ? ((actionT - .42) / .16).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final tackleKick = _state == _PlayerAnimState.tackle
        ? sin((((actionT - .26) / .16).clamp(0.0, 1.0).toDouble()) * pi)
        : 0.0;
    final saveLean = _state == _PlayerAnimState.save
        ? ((_actionTime / _actionDuration).clamp(0.0, 1.0).toDouble() * 0.18)
        : 0.0;

    canvas.save();
    canvas.translate(0, -goalCelebrationLift);
    canvas.translate((subInT * 8) - (subOutT * 8), 0);
    canvas.scale(1.0 - subOutT * .22, 1.0 - subOutT * .22);
    canvas.rotate(_facing);
    if (_state == _PlayerAnimState.save) {
      canvas.rotate(saveLean);
    }
    if (_state == _PlayerAnimState.receive) {
      final openAngle = (-.10 * receivePrep + .16 * receiveTurn);
      canvas.rotate(openAngle);
    }
    canvas.skew(-_lean * .08, _lean * .04);
    if (_state == _PlayerAnimState.shoot) {
      canvas.rotate(-.08 * shotAnticipation + .12 * Curves.easeOut.transform(shotRelease));
    }

    // Ground shadow anchors the player to the pitch.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 7), width: 15 + intensity * 5, height: 5),
      Paint()..color = Colors.black.withValues(alpha: .28),
    );

    if (_possessionPulse > 0) {
      final a = (_possessionPulse / .22).clamp(0.0, 1.0);
      canvas.drawCircle(Offset.zero, 13 + (1 - a) * 5, Paint()..color = Colors.white.withValues(alpha: a * .28));
    }

    if (_state == _PlayerAnimState.substitutionIn || _state == _PlayerAnimState.substitutionOut) {
      final subPulse = sin(actionT * pi);
      canvas.drawCircle(Offset.zero, 12 + subPulse * 5, Paint()..color = Colors.white.withValues(alpha: .22 * subPulse));
    }

    if (hasBall) {
      final pulse = 1 + sin(_animTime * 7) * .08;
      canvas.drawCircle(
        Offset.zero,
        12.5 * pulse,
        Paint()..color = Colors.white.withValues(alpha: .16),
      );
    }

    if (_state == _PlayerAnimState.tackle) {
      // Directional challenge cue: the player visibly commits weight
      // before the contact beat, then opens back into recovery.
      final challengeAlpha = (.18 + .52 * (1 - tackleRecovery)).clamp(0.0, 1.0).toDouble();
      canvas.drawArc(
        Rect.fromCenter(center: Offset(2 + tackleApproach * 3, 3), width: 25 + tackleContact * 5, height: 14),
        pi * .1,
        pi * .8,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: challengeAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (tackleContact > .02) {
        canvas.drawCircle(
          Offset(8 + tackleKick * .35, 6),
          2.5 + tackleContact * 5,
          Paint()..color = Colors.white.withValues(alpha: tackleContact * .38),
        );
      }
    }

    // Legs: simple procedural run cycle. This is deliberately readable at
    // small sizes and provides a direct path to sprite replacement later.
    final legPaint = Paint()
      ..color = Colors.white.withValues(alpha: .9)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final contactLunge = _contactStrength * 3.8;
    final saveKick = _state == _PlayerAnimState.save
        ? (5.0 * _saveDive + 8.0 * _saveReach - 4.0 * _saveRecovery)
        : 0.0;
    final saveReachY = _state == _PlayerAnimState.save
        ? _saveDirection.y * (3.0 + _saveReach * 6.0)
        : 0.0;
    final receiveKick = _state == _PlayerAnimState.receive ? 2.8 * sin(actionT * pi) : 0.0;
    final passPreparation = _state == _PlayerAnimState.pass
        ? Curves.easeOut.transform((actionT / .34).clamp(0.0, 1.0))
        : 0.0;
    final passRelease = _state == _PlayerAnimState.pass
        ? ((actionT - .34) / .38).clamp(0.0, 1.0)
        : 0.0;
    final passKick = _state == _PlayerAnimState.pass
        ? (-5.5 * passPreparation) + (10.0 * Curves.easeOut.transform(passRelease))
        : 0.0;
    final dribbleKick = _state == _PlayerAnimState.dribble
        ? dribbleSide + dribbleTouchBeat * 1.5
        : 0.0;
    final legKick = _state == _PlayerAnimState.shoot
        ? shootKick
        : (_state == _PlayerAnimState.tackle
            ? tackleKick
            : (_state == _PlayerAnimState.receive
                ? receiveKick
                : (_state == _PlayerAnimState.pass
                    ? passKick
                    : (stride + dribbleKick))));
    canvas.translate(
      _contactDirection.x * contactLunge + dribbleFeintX,
      _contactDirection.y * contactLunge + dribbleFeintY,
    );
    canvas.drawLine(const Offset(-2, 4), Offset(-4 + legKick, 9), legPaint);
    canvas.drawLine(const Offset(2, 4), Offset(4 - legKick, 9), legPaint);
    if (_state == _PlayerAnimState.save) {
      final diveFoot = 4 + _saveDive * 6 - _saveRecovery * 2;
      canvas.drawLine(const Offset(-2, 3), Offset(-7 - diveFoot, 0 + saveReachY * .35), legPaint);
      canvas.drawLine(const Offset(2, 3), Offset(7 + diveFoot, 0 - saveReachY * .35), legPaint);
    }

    // Body and head.
    final shotBodyDip = _state == _PlayerAnimState.shoot ? 1.8 * shotAnticipation - 1.2 * shotRecovery : 0.0;
    final bodyY = bob - 1 + injuredLean + touchCrouch + shotBodyDip -
        dribbleIntensity * .55;
    final bodyScale = _state == _PlayerAnimState.tackle
        ? 1 + .10 * tackleApproach + .06 * tackleContact - .06 * tackleRecovery
        : 1.0;
    canvas.scale(bodyScale, 1 / bodyScale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, bodyY), width: 8.5, height: 10),
        const Radius.circular(3),
      ),
      Paint()..color = isGoalkeeper ? const Color(0xFFFFC107) : color,
    );
    canvas.drawCircle(Offset(0, bodyY - 7), 3.2, Paint()..color = const Color(0xFFF0C7A4));

    // Arms react to action state.
    final armPaint = Paint()
      ..color = const Color(0xFFF0C7A4)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final armSpread = _state == _PlayerAnimState.celebrate ? 7.0 : 4.0 + intensity * 1.5;
    final receiveSpread = _state == _PlayerAnimState.receive
        ? 5.0 * (1 - receivePrep) + 3.0 * receiveContact + 1.8 * receiveTurn
        : 0.0;
    final saveSpread = _state == _PlayerAnimState.save ? 9.0 * _saveDive : 0.0;
    final saveReachX = _state == _PlayerAnimState.save ? _saveDirection.x * (4 + _saveReach * 8) : 0.0;
    final saveReachArmY = _state == _PlayerAnimState.save ? _saveDirection.y * (3 + _saveReach * 7) : 0.0;
    canvas.drawLine(Offset(-3.5, bodyY - 2), Offset(-armSpread - receiveSpread - saveSpread + saveReachX, bodyY + stride * .25 + saveReachArmY), armPaint);
    canvas.drawLine(Offset(3.5, bodyY - 2), Offset(armSpread + receiveSpread + saveSpread + saveReachX, bodyY - stride * .25 + saveReachArmY), armPaint);
    if (_state == _PlayerAnimState.tackle && actionT < 1) {
      final brace = tacklePlant * 3.0 + tackleContact * 2.5 - tackleRecovery * 2.0;
      canvas.drawLine(
        Offset(-3.5, bodyY - 2),
        Offset(-5.5 - brace, bodyY + 2.5 + tackleContact),
        armPaint,
      );
      canvas.drawLine(
        Offset(3.5, bodyY - 2),
        Offset(5.5 + brace, bodyY + 1.5 - tackleContact),
        armPaint,
      );
    }

    if (_state == _PlayerAnimState.save && _saveReach > .05) {
      final glove = Offset(
        _saveDirection.x * (7 + _saveReach * 9),
        bodyY + _saveDirection.y * (5 + _saveReach * 8),
      );
      canvas.drawCircle(glove, 2.0 + _saveReach * 1.8, Paint()..color = Colors.white.withValues(alpha: .86));
      canvas.drawArc(
        Rect.fromCircle(center: glove, radius: 4 + _saveReach * 3),
        -.9, 1.8, false,
        Paint()..color = Colors.white.withValues(alpha: .28 * _saveReach)..style = PaintingStyle.stroke..strokeWidth = 1.2,
      );
    }

    // Action-specific contact marker makes the exact gameplay beat readable.
    if (_contactFlash > 0) {
      final a = (_contactFlash / .16).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(8, 3), 3 + (1 - a) * 5, Paint()..color = Colors.white.withValues(alpha: a * .65));
    }

    // Dribble control cue: alternating foot touches and a short protective
    // arc make ball carrying readable without inventing authoritative ball
    // coordinates in the renderer.
    if (_state == _PlayerAnimState.dribble && hasBall && dribbleIntensity > .01) {
      final side = sin(_dribblePhase) * 4.0;
      final foot = Offset(5.2 + side, 7.2 - sin(_dribblePhase).abs() * 1.8);
      canvas.drawLine(
        Offset(2, 4),
        foot,
        legPaint,
      );
      canvas.drawCircle(
        foot,
        1.5 + dribbleTouchBeat.abs() * 1.2,
        Paint()..color = Colors.white.withValues(alpha: .78),
      );
      final shieldCenter = Offset(-dribbleFeintX * .7, -dribbleFeintY * .7);
      canvas.drawArc(
        Rect.fromCenter(center: shieldCenter, width: 13, height: 10),
        -.9 + _dribbleFeint * .18,
        1.8,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: .18 + dribbleIntensity * .12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }

    // Directional first-touch cue: the body subtly opens toward the
    // incoming ball path so the first touch reads as a deliberate
    // cushioning action rather than a generic possession switch.
    if (_firstTouchStrength > 0.01) {
      final cue = _firstTouchStrength * 2.2;
      canvas.drawLine(
        Offset(touchDirX * 2, bodyY + touchDirY * 1.5),
        Offset(touchDirX * (5 + cue), bodyY + touchDirY * (3 + cue)),
        legPaint,
      );
    }

    // First-touch foot cushioning: the receiving leg reaches toward the
    // incoming ball, then retracts into the next locomotion step.
    if (_state == _PlayerAnimState.receive && actionT < 1) {
      // Receiving 2.0: scan/open body -> plant -> cushioning contact ->
      // protect the ball -> turn into the next action.
      final cushion = receiveContact * (1 - receiveRelease * .55);
      final protection = receiveRelease * .9;
      final touchFoot = Offset(
        5.5 + receiveKick * 1.4 + touchDirX * (3.2 + cushion * 2.2) - touchDirY * protection * 2.2,
        7 - actionStrength * .9 + touchDirY * (1.5 + cushion * 2.0) + touchDirX * protection * 1.8,
      );
      final plant = Offset(-3.5 - receivePrep * 1.4, 8);
      canvas.drawCircle(plant, 1.5 + receivePrep * .5, Paint()..color = Colors.white.withValues(alpha: .72));
      canvas.drawLine(const Offset(2, 4), touchFoot, legPaint);
      canvas.drawCircle(touchFoot, 1.7 + cushion * 1.1, Paint()..color = Colors.white.withValues(alpha: .9));

      if (receiveContact > .05) {
        canvas.drawArc(
          Rect.fromCircle(center: touchFoot, radius: 4.5 + receiveContact * 3.5),
          -.8, 1.1, false,
          Paint()..color = Colors.white.withValues(alpha: receiveContact * .35)..style = PaintingStyle.stroke..strokeWidth = 1.0,
        );
      }

      if (_receiveProtectsBall && receiveRelease > .05) {
        final shield = Offset(-touchDirY * 3.2, touchDirX * 3.2);
        canvas.drawArc(
          Rect.fromCircle(center: shield, radius: 8 + receiveRelease * 2),
          -1.2, 2.2, false,
          Paint()..color = Colors.white.withValues(alpha: receiveRelease * .24)..style = PaintingStyle.stroke..strokeWidth = 1.2,
        );
      }

      if (receiveTurn > .08) {
        canvas.drawLine(
          Offset(touchDirX * 2, touchDirY * 2),
          Offset(touchDirX * (7 + receiveTurn * 3), touchDirY * (7 + receiveTurn * 3)),
          legPaint,
        );
      }
    }

    // Passing animation: plant foot, backswing, contact and follow-through.
    // The release beat is intentionally readable even at small pitch scale.
    if (_state == _PlayerAnimState.pass && actionT < 1) {
      final plant = Offset(-4 - passPreparation * 1.8, 8);
      final passFoot = Offset(5 + passKick, 7 - passRelease * 2.0);
      canvas.drawCircle(plant, 1.6 + passPreparation * .5, Paint()..color = Colors.white.withValues(alpha: .72));
      canvas.drawLine(const Offset(2, 4), passFoot, legPaint);
      canvas.drawCircle(passFoot, 1.6 + passRelease * .6, Paint()..color = Colors.white.withValues(alpha: .92));

      final armDrive = passPreparation * 2.8 + passRelease * 3.2;
      canvas.drawLine(Offset(-3.5, bodyY - 2), Offset(-5.5 - armDrive, bodyY + 1), armPaint);
      canvas.drawLine(Offset(3.5, bodyY - 2), Offset(5.5 + armDrive, bodyY - 1), armPaint);

      if (passRelease > .08) {
        final a = .42 * (1 - passRelease);
        canvas.drawArc(
          Rect.fromCircle(center: passFoot, radius: 4.5 + passRelease * 4),
          -.9, .75, false,
          Paint()..color = Colors.white.withValues(alpha: a)..style = PaintingStyle.stroke..strokeWidth = 1.1,
        );
      }
    }

    // Shooting 2.0: approach/plant -> wind-up -> contact -> release ->
    // follow-through -> recovery. The simulation decides the shot; this
    // presentation layer makes each physical beat readable.
    if (_state == _PlayerAnimState.shoot && actionT < 1) {
      final plant = Offset(-4.5 - shotAnticipation * 1.5, 8.2);
      final footX = 5 - shotAnticipation * 4 + Curves.easeOut.transform(shotRelease) * 15 - shotRecovery * 3;
      final footY = 8 - shotAnticipation * 2.0 - Curves.easeOut.transform(shotRelease) * 4.2 + shotRecovery * 2.5;
      final foot = Offset(footX, footY);
      canvas.drawCircle(plant, 1.7 + shotAnticipation * .8, Paint()..color = Colors.white.withValues(alpha: .65));
      canvas.drawLine(const Offset(2, 4), foot, legPaint);
      canvas.drawCircle(foot, 1.8 + shotContact * 1.2 + shotRelease * .6, Paint()..color = Colors.white);

      if (shotContact > .05 && shotContact < 1) {
        final contactAlpha = sin(shotContact * pi);
        canvas.drawCircle(foot, 3 + contactAlpha * 4, Paint()..color = Colors.white.withValues(alpha: contactAlpha * .45));
        canvas.drawLine(Offset(foot.dx - 2, foot.dy), Offset(foot.dx + 6, foot.dy), Paint()..color = Colors.white.withValues(alpha: contactAlpha * .45)..strokeWidth = 1.1);
      }

      if (shotRelease > .02) {
        canvas.drawArc(
          Rect.fromCircle(center: foot, radius: 5 + shotRelease * 6),
          -1.15,
          1.0,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: .40 * (1 - shotRelease))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25,
        );
      }

      final shotArm = 3 + shotAnticipation * 3 + shotRelease * 4;
      canvas.drawLine(Offset(-3.5, bodyY - 2), Offset(-shotArm, bodyY + 1.5), armPaint);
      canvas.drawLine(Offset(3.5, bodyY - 2), Offset(shotArm + 1, bodyY - 1.5), armPaint);
    }

    // Tackle/sprint dust gives the ground contact a stronger sense of speed.
    if (_state == _PlayerAnimState.tackle && actionStrength > .05) {
      final dust = Paint()..color = Colors.white.withValues(alpha: actionStrength * .18);
      canvas.drawCircle(Offset(-8, 7), 2 + actionStrength * 3, dust);
      canvas.drawCircle(Offset(-13, 8), 1.5 + actionStrength * 2, dust);
    }

    canvas.restore();

    // Shirt number stays upright/readable even while the player turns.
    final tp = TextPainter(
      text: TextSpan(
        text: '$shirtNumber',
        style: const TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2 - .5));

    if (redCard || yellowCard) {
      final cardColor = redCard ? const Color(0xFFE53935) : const Color(0xFFFDD835);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(11, -10), width: 5, height: 7),
          const Radius.circular(1),
        ),
        Paint()..color = cardColor,
      );
    }

    if (injured) {
      canvas.drawCircle(Offset(0, -13), 2, Paint()..color = const Color(0xFFFF5252));
    }
  }
}

class _BallDot extends PositionComponent {
  _BallDot({required List<Vector2> trail}) : _trail = trail, super(anchor: Anchor.center);

  double targetX = 0;
  double targetY = 0;
  double _spin = 0;
  bool isTravelling = false;
  double shotPulse = 0;
  double _speed = 0;
  Vector2 velocity = Vector2.zero();
  @override
  double height = 0;
  double contactFlash = 0;
  double spinRate = 0;
  double bounce = 0;
  final List<Vector2>? _trail;

  static const double _followSpeed = 11.0;

  @override
  void update(double dt) {
    super.update(dt);
    final target = Vector2(targetX, targetY);
    final delta = target - position;
    final dist = delta.length;
    _speed = dist / max(dt, 0.0001);
    if (dist < 0.05) {
      position.setFrom(target);
      _speed = 0;
    } else {
      final step = min(dist, dist * _followSpeed * dt);
      position += delta.normalized() * step;
    }
    _spin += dt * (_speed * .018 + 2.0 + spinRate.abs() * 0.35);
    bounce = max(0, bounce - dt * 3.8);
  }

  @override
  void render(Canvas canvas) {
    // Short motion trail: intentionally subtle so it reads as speed, not as
    // a cartoon effect. The actual ball position remains authoritative.
    if (isTravelling && _trail != null) {
      for (var i = 0; i < _trail!.length; i++) {
        final point = _trail![i];
        final a = (i + 1) / _trail!.length * .16;
        canvas.drawCircle(Offset(point.x - position.x, point.y - position.y), 1.2 + i * .05, Paint()..color = Colors.white.withValues(alpha: a));
      }
    }
    final stretch = isTravelling ? min(1.8, 1 + _speed / 650) : 1.0;
    if (contactFlash > 0) {
      final a = (contactFlash / .20).clamp(0.0, 1.0);
      canvas.drawCircle(Offset.zero, 6 + (1 - a) * 6, Paint()..color = Colors.white.withValues(alpha: a * .22));
    }
    if (shotPulse > 0) {
      final a = (shotPulse / .62).clamp(0.0, 1.0);
      canvas.drawCircle(Offset.zero, 7 + (1 - a) * 9, Paint()..color = Colors.white.withValues(alpha: a * .18));
    }
    final bounceLift = 3.5 * sin(bounce * pi).abs();
    final lift = min(18.0, height) + bounceLift;
    final shadowScale = (1.0 - lift / 24).clamp(.55, 1.0);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 4), width: 8 * stretch * shadowScale, height: 3 * shadowScale),
      Paint()..color = Colors.black.withValues(alpha: .35 * shadowScale),
    );
    canvas.save();
    canvas.translate(0, -lift);
    canvas.rotate(_spin);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 9 * stretch, height: 9),
      Paint()..color = Colors.white,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 9 * stretch, height: 9),
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawLine(Offset.zero, Offset(0, -4.5), Paint()..color = Colors.black45..strokeWidth = 1);
    canvas.restore();
  }
}



class _BallContactMark extends PositionComponent {
  _BallContactMark({required Vector2 position})
      : super(position: position, anchor: Anchor.center);

  double _age = 0;
  static const double _life = .20;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final a = (1 - t) * .55;
    final r = 2 + t * 7;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset.zero, r, paint);
    canvas.drawLine(Offset(-r - 2, 0), Offset(-r + 2, 0), paint);
    canvas.drawLine(Offset(r - 2, 0), Offset(r + 2, 0), paint);
  }
}

class _PassRelease extends PositionComponent {
  _PassRelease({required Vector2 position}) : super(position: position, anchor: Anchor.center);

  double _age = 0;
  static const double _life = .24;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final a = (1 - t) * .45;
    final r = 2.5 + t * 6.5;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset.zero, r, paint);
    canvas.drawLine(Offset(-r - 1, 0), Offset(-r + 2, 0), paint);
    canvas.drawLine(Offset(r - 2, 0), Offset(r + 1, 0), paint);
  }
}

class _ShotImpact extends PositionComponent {
  _ShotImpact({required Vector2 position}) : super(position: position, anchor: Anchor.center);

  double _age = 0;
  static const _life = .28;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final a = (1 - t) * .5;
    final r = 3 + t * 9;
    canvas.drawCircle(Offset.zero, r, Paint()
      ..color = Colors.white.withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }
}

class _ActionRing extends PositionComponent {
  _ActionRing({required Vector2 position, required this.kind}) : super(position: position, anchor: Anchor.center);

  final Match2DEventType kind;
  double _age = 0;
  static const _life = .42;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final radius = 4 + t * (kind == Match2DEventType.goal ? 28 : 16);
    final alpha = (1 - t) * .55;
    canvas.drawCircle(Offset.zero, radius, Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = kind == Match2DEventType.goal ? 2.5 : 1.5);
  }
}

class _PlayerContactBurst extends PositionComponent {
  _PlayerContactBurst({required Vector2 position})
      : super(position: position, anchor: Anchor.center);

  double _age = 0;
  static const double _life = .22;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final alpha = (1 - t) * .38;
    final radius = 2 + t * 7;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawCircle(Offset.zero, radius, paint);
    for (var i = 0; i < 4; i++) {
      final angle = i * pi / 2 + pi / 4;
      canvas.drawLine(
        Offset(cos(angle) * 2, sin(angle) * 2),
        Offset(cos(angle) * (4 + t * 5), sin(angle) * (4 + t * 5)),
        paint,
      );
    }
  }
}

class _ContactBurst extends PositionComponent {
  _ContactBurst({required Vector2 position}) : super(position: position, anchor: Anchor.center);

  double _age = 0;
  static const double _life = .28;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final alpha = (1 - t) * .45;
    final radius = 3 + t * 9;
    canvas.drawCircle(Offset.zero, radius, Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
    for (var i = 0; i < 4; i++) {
      final angle = i * pi / 2;
      final start = Offset(cos(angle) * 2, sin(angle) * 2);
      final end = Offset(cos(angle) * (5 + t * 6), sin(angle) * (5 + t * 6));
      canvas.drawLine(start, end, Paint()..color = Colors.white.withValues(alpha: alpha));
    }
  }
}

class _GoalSequenceBanner extends PositionComponent {
  _GoalSequenceBanner({required Vector2 position, this.scorerLabel})
      : super(position: position, anchor: Anchor.center);

  final String? scorerLabel;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age > 2.8) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final fadeIn = (_age / .22).clamp(0.0, 1.0);
    final fadeOut = ((2.8 - _age) / .55).clamp(0.0, 1.0);
    final alpha = min(fadeIn, fadeOut);
    final scale = .82 + .18 * Curves.easeOutBack.transform(fadeIn);
    canvas.save();
    canvas.scale(scale, scale);
    final title = TextPainter(
      text: TextSpan(
        text: 'GOAL!',
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha),
          fontSize: 34,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, Offset(-title.width / 2, -16));
    if (scorerLabel != null) {
      final sub = TextPainter(
        text: TextSpan(
          text: 'PLAYER #$scorerLabel',
          style: TextStyle(
            color: Colors.white.withValues(alpha: alpha * .9),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      sub.paint(canvas, Offset(-sub.width / 2, 22));
    }
    canvas.restore();
  }
}

class _ReplayBanner extends PositionComponent {
  _ReplayBanner(this.director) : super(anchor: Anchor.center, priority: 2000);

  final MatchReplayDirector director;

  @override
  void render(Canvas canvas) {
    if (!director.isPlaying) return;
    final alpha = (0.78 + sin(director.progress * pi * 2) * .12).clamp(.45, .95);
    final width = 170.0;
    final height = 46.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = Colors.black.withValues(alpha: .72 * alpha),
    );
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: .24 * alpha);
    canvas.drawRRect(rect, border);

    final label = director.trigger == Match2DEventType.goal
        ? 'REPLAY • GOAL'
        : director.trigger == Match2DEventType.save
            ? 'REPLAY • SAVE'
            : director.trigger == Match2DEventType.shot
                ? 'REPLAY • SHOT'
                : 'REPLAY • KEY MOMENT';
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.7,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(-text.width / 2, -13));

    final bar = Rect.fromLTWH(-65, 11, 130, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: .16),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-65, 11, 130 * director.progress, 3),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withValues(alpha: .9),
    );
  }
}

class _GoalSequenceFlash extends PositionComponent {
  _GoalSequenceFlash({required Vector2 position})
      : super(position: position, anchor: Anchor.center);

  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t > .55) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / .55).clamp(0.0, 1.0);
    final radius = 12 + p * 58;
    final alpha = (1 - p) * .55;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * (1 - p * .6)
      ..color = Colors.white.withValues(alpha: alpha);
    canvas.drawCircle(Offset.zero, radius, paint);
  }
}

class _GoalBurst extends PositionComponent {
  _GoalBurst({required Vector2 position}) : super(position: position, anchor: Anchor.center);

  double _age = 0;
  static const double _lifespan = 1.1;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _lifespan) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _lifespan).clamp(0.0, 1.0);
    final radius = 6 + t * 46;
    final alpha = (1 - t).clamp(0.0, 1.0);

    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: alpha * .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    const sparkCount = 8;
    for (var i = 0; i < sparkCount; i++) {
      final angle = (i / sparkCount) * 2 * pi;
      final dist = radius * .8;
      canvas.drawCircle(
        Offset(cos(angle) * dist, sin(angle) * dist),
        3 * (1 - t),
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }
}


class _SubstitutionSequenceBanner extends PositionComponent {
  _SubstitutionSequenceBanner({required Vector2 position, required this.incomingName, required this.outgoingName, this.incomingNumber, this.outgoingNumber})
      : super(position: position, anchor: Anchor.center);
  final String incomingName;
  final String outgoingName;
  final int? incomingNumber;
  final int? outgoingNumber;
  double _age = 0;
  @override void update(double dt) { super.update(dt); _age += dt; if (_age > 3.2) removeFromParent(); }
  @override void render(Canvas canvas) {
    final inT = (_age / .22).clamp(0.0, 1.0);
    final outT = ((3.2 - _age) / .55).clamp(0.0, 1.0);
    final a = min(inT, outT);
    final scale = .86 + .14 * Curves.easeOutBack.transform(inT);
    canvas.save(); canvas.scale(scale, scale);
    final title = TextPainter(text: TextSpan(text: 'SUBSTITUTION', style: TextStyle(color: Colors.white.withValues(alpha: a), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)), textDirection: TextDirection.ltr)..layout();
    title.paint(canvas, Offset(-title.width / 2, -28));
    final line = TextPainter(text: TextSpan(children: [TextSpan(text: '↓  ${outgoingNumber == null ? '' : '#$outgoingNumber '}$outgoingName', style: TextStyle(color: Colors.white.withValues(alpha: a * .72), fontSize: 11, fontWeight: FontWeight.w700)), TextSpan(text: '    ↑  ${incomingNumber == null ? '' : '#$incomingNumber '}$incomingName', style: TextStyle(color: Colors.white.withValues(alpha: a), fontSize: 12, fontWeight: FontWeight.w900))]), textDirection: TextDirection.ltr)..layout();
    line.paint(canvas, Offset(-line.width / 2, 2));
    final hint = TextPainter(text: TextSpan(text: 'CHANGE IN PROGRESS', style: TextStyle(color: Colors.white.withValues(alpha: a * .6), fontSize: 8, letterSpacing: 1.4, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
    hint.paint(canvas, Offset(-hint.width / 2, 22));
    canvas.restore();
  }
}

class _SubstitutionTouchlineBurst extends PositionComponent {
  _SubstitutionTouchlineBurst({required Vector2 position}) : super(position: position, anchor: Anchor.center);
  double _age = 0;
  @override void update(double dt) { super.update(dt); _age += dt; if (_age > .7) removeFromParent(); }
  @override void render(Canvas canvas) {
    final t = (_age / .7).clamp(0.0, 1.0); final a = (1 - t) * .42;
    canvas.drawCircle(Offset.zero, 7 + t * 24, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white.withValues(alpha: a));
    canvas.drawLine(Offset(-10 - t * 5, 0), Offset(10 + t * 5, 0), Paint()..color = Colors.white.withValues(alpha: a * .7)..strokeWidth = 1.5);
  }
}
