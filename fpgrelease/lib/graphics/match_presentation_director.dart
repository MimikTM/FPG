import 'dart:math';
import '../models/match_2d.dart';

/// Matchday orchestration state for presentation systems.
///
/// This class is deliberately presentation-only: Match2DEngine remains the
/// authoritative source of match state, score, events and transactions.
/// Camera, HUD, crowd and audio consumers can all read the same phase/event
/// decision without creating their own competing state machines.
enum MatchPresentationPhase {
  intro,
  lineup,
  live,
  halftime,
  secondHalf,
  fulltime,
  postMatch,
}

class MatchPresentationDirector {
  MatchPresentationPhase phase = MatchPresentationPhase.intro;
  Match2DEventType? activeEvent;
  String? activePlayerId;
  double eventTimer = 0;
  double intensity = 0;
  int eventSequence = 0;
  String? _lastEventKey;

  bool get blocksMatchClock =>
      phase == MatchPresentationPhase.intro ||
      phase == MatchPresentationPhase.lineup ||
      phase == MatchPresentationPhase.halftime;

  bool get isLive => phase == MatchPresentationPhase.live || phase == MatchPresentationPhase.secondHalf;
  bool get isTerminal => phase == MatchPresentationPhase.fulltime || phase == MatchPresentationPhase.postMatch;

  void reset() {
    phase = MatchPresentationPhase.intro;
    activeEvent = null;
    activePlayerId = null;
    eventTimer = 0;
    intensity = 0;
    eventSequence = 0;
    _lastEventKey = null;
  }

  void enter(MatchPresentationPhase next) {
    phase = next;
    if (next == MatchPresentationPhase.live || next == MatchPresentationPhase.secondHalf) {
      clearEvent();
    }
  }

  void beginIntro() => enter(MatchPresentationPhase.intro);
  void beginLineup() => enter(MatchPresentationPhase.lineup);
  void beginLive() => enter(MatchPresentationPhase.live);
  void beginSecondHalf() => enter(MatchPresentationPhase.secondHalf);
  void beginHalftime() => enter(MatchPresentationPhase.halftime);
  void beginFulltime() => enter(MatchPresentationPhase.fulltime);
  void beginPostMatch() => enter(MatchPresentationPhase.postMatch);

  /// Registers an authoritative simulation event for all presentation
  /// consumers. It does not mutate the event or the match engine.
  void onEvent(Match2DEvent event) {
    // MatchScreen and PitchGame can both observe the same authoritative
    // event. Deduplicate it here so timers/intensity/sequence advance once.
    final key = '${event.minute}|${event.type}|${event.playerId}|${event.secondaryPlayerId}|${event.description}';
    if (_lastEventKey == key) return;
    _lastEventKey = key;
    eventSequence++;
    activeEvent = event.type;
    activePlayerId = event.playerId;
    switch (event.type) {
      case Match2DEventType.goal:
        eventTimer = 3.4;
        intensity = 1.0;
        break;
      case Match2DEventType.shot:
      case Match2DEventType.save:
        eventTimer = .9;
        intensity = .72;
        break;
      case Match2DEventType.foul:
      case Match2DEventType.card:
      case Match2DEventType.injury:
        eventTimer = 1.25;
        intensity = .58;
        break;
      case Match2DEventType.substitution:
        eventTimer = 2.3;
        intensity = .48;
        break;
      case Match2DEventType.halftime:
        beginHalftime();
        eventTimer = 1.8;
        intensity = .62;
        break;
      case Match2DEventType.fulltime:
        beginFulltime();
        eventTimer = 2.4;
        intensity = 1.0;
        break;
      default:
        eventTimer = 0;
        intensity = .25;
    }
  }

  void update(double dt) {
    eventTimer = max(0, eventTimer - dt);
    intensity = max(0, intensity - dt * .7);
    if (eventTimer <= 0 && activeEvent != null) clearEvent();
  }

  void clearEvent() {
    activeEvent = null;
    activePlayerId = null;
    eventTimer = 0;
    intensity = 0;
  }
}
