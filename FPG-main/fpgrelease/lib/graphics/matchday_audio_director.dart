import 'dart:async';
import '../core/audio_service.dart';
import '../models/match_2d.dart';

/// Presentation-only audio state machine for Matchday.
/// Gameplay remains authoritative; this class only routes existing audio assets.
class MatchdayAudioDirector {
  Match2DEventType? activeEvent;
  String? phase;
  double crowdEnergy = .45;
  Timer? _clearTimer;

  void reset() {
    _clearTimer?.cancel();
    activeEvent = null;
    phase = null;
    crowdEnergy = .45;
  }

  void beginIntro() {
    phase = 'MATCH INTRO';
    _play(FPGAudio.countdown);
  }

  void beginLineup() {
    phase = 'STARTING XI';
    _play(FPGAudio.crowd);
  }

  void beginLive() {
    phase = 'LIVE';
    crowdEnergy = .5;
  }

  void beginHalftime() {
    phase = 'HALF TIME';
    _play(FPGAudio.countdown);
    _pulse(null, 2.5);
  }

  void beginSecondHalf() {
    phase = '2ND HALF';
    _play(FPGAudio.countdown);
  }

  void beginFulltime() {
    phase = 'FULL TIME';
    _play(FPGAudio.crowd);
    _pulse(null, 3.0);
  }

  void beginPostMatch() {
    phase = 'MATCH REPORT';
    activeEvent = null;
  }

  void onEvent(Match2DEvent event) {
    activeEvent = event.type;
    switch (event.type) {
      case Match2DEventType.goal:
        crowdEnergy = 1.0;
        _play(FPGAudio.goal);
        _pulse(event.type, 3.2);
        break;
      case Match2DEventType.shot:
        crowdEnergy = .72;
        _play(FPGAudio.kick);
        _pulse(event.type, 1.2);
        break;
      case Match2DEventType.save:
        crowdEnergy = .78;
        _play(FPGAudio.kick);
        _pulse(event.type, 1.5);
        break;
      case Match2DEventType.foul:
      case Match2DEventType.card:
        crowdEnergy = .62;
        _play(FPGAudio.crowd);
        _pulse(event.type, 1.4);
        break;
      case Match2DEventType.halftime:
        beginHalftime();
        break;
      case Match2DEventType.fulltime:
        beginFulltime();
        break;
      default:
        _play(FPGAudio.crowd);
        _pulse(event.type, 1.0);
    }
  }

  void update(double dt) {
    crowdEnergy += (.5 - crowdEnergy) * (dt * .8).clamp(0, 1);
  }

  void dispose() {
    _clearTimer?.cancel();
  }

  void _pulse(Match2DEventType? type, double seconds) {
    activeEvent = type;
    _clearTimer?.cancel();
    _clearTimer = Timer(Duration(milliseconds: (seconds * 1000).round()), () {
      activeEvent = null;
    });
  }

  void _play(String asset) {
    unawaited(FPGAudio.playSfx(asset));
  }
}
