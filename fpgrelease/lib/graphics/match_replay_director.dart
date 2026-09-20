import 'dart:math';
import '../models/match_2d.dart';

/// Presentation-only replay buffer. It never mutates Match2DEngine.
///
/// A key moment is replayed from a short ring-buffer of already-rendered
/// match-space snapshots. The authoritative simulation continues in the
/// background; only the visual layer is temporarily driven by these samples.
class MatchReplayDirector {
  MatchReplayDirector({
    this.sampleInterval = 1 / 15,
    this.maxDuration = 3.0,
    this.playbackSpeed = 0.82,
  });

  final double sampleInterval;
  final double maxDuration;
  final double playbackSpeed;

  final List<MatchReplaySnapshot> _buffer = <MatchReplaySnapshot>[];
  List<MatchReplaySnapshot> _clip = const <MatchReplaySnapshot>[];
  double _sampleTimer = 0;
  double _playbackTime = 0;
  bool _playing = false;
  Match2DEventType? _trigger;

  bool get isPlaying => _playing;
  Match2DEventType? get trigger => _trigger;
  double get progress {
    if (!_playing || _clip.length < 2) return 0;
    final duration = (_clip.length - 1) * sampleInterval;
    return duration <= 0 ? 1 : (_playbackTime / duration).clamp(0.0, 1.0);
  }

  MatchReplaySnapshot? get current {
    if (!_playing || _clip.isEmpty) return null;
    final position = (_playbackTime / sampleInterval)
        .clamp(0.0, (_clip.length - 1).toDouble());
    final index = position.floor();
    final next = min(index + 1, _clip.length - 1);
    final t = position - index;
    return MatchReplaySnapshot.interpolate(_clip[index], _clip[next], t);
  }

  void reset() {
    _buffer.clear();
    _clip = const <MatchReplaySnapshot>[];
    _sampleTimer = 0;
    _playbackTime = 0;
    _playing = false;
    _trigger = null;
  }

  void record(Match2DState state, double dt) {
    _sampleTimer += dt;
    if (_sampleTimer < sampleInterval) return;
    _sampleTimer = 0;

    _buffer.add(MatchReplaySnapshot.fromState(state));
    final maxSamples = max(2, (maxDuration / sampleInterval).ceil() + 2);
    if (_buffer.length > maxSamples) {
      _buffer.removeRange(0, _buffer.length - maxSamples);
    }
  }

  /// Starts a replay using the most recent ~2.3 seconds, plus the triggering
  /// frame. Goal/save/shot/key-moment events are intended callers.
  bool triggerReplay(Match2DEventType type) {
    if (_playing || _buffer.length < 3) return false;
    final desired = max(3, (2.35 / sampleInterval).round());
    final start = max(0, _buffer.length - desired);
    _clip = List<MatchReplaySnapshot>.from(_buffer.sublist(start));
    _playbackTime = 0;
    _playing = true;
    _trigger = type;
    return true;
  }

  void update(double dt) {
    if (!_playing) return;
    _playbackTime += dt * playbackSpeed;
    final duration = max(0.0, (_clip.length - 1) * sampleInterval);
    if (_playbackTime >= duration) {
      _playing = false;
      _playbackTime = 0;
      _clip = const <MatchReplaySnapshot>[];
      _trigger = null;
    }
  }
}

class MatchReplaySnapshot {
  MatchReplaySnapshot({
    required this.players,
    required this.ballX,
    required this.ballY,
    required this.ballHeight,
    required this.minute,
    required this.homeGoals,
    required this.awayGoals,
  });

  final Map<String, MatchReplayPlayer> players;
  final double ballX;
  final double ballY;
  final double ballHeight;
  final int minute;
  final int homeGoals;
  final int awayGoals;

  factory MatchReplaySnapshot.fromState(Match2DState state) {
    return MatchReplaySnapshot(
      players: {
        for (final p in state.players)
          if (p.active)
            p.id: MatchReplayPlayer(
              x: p.x,
              y: p.y,
              hasBall: p.hasBall,
              shirtNumber: p.shirtNumber,
            ),
      },
      ballX: state.ballX,
      ballY: state.ballY,
      ballHeight: state.ballHeight,
      minute: state.minute,
      homeGoals: state.homeGoals,
      awayGoals: state.awayGoals,
    );
  }

  static MatchReplaySnapshot interpolate(
    MatchReplaySnapshot a,
    MatchReplaySnapshot b,
    double t,
  ) {
    final ids = <String>{...a.players.keys, ...b.players.keys};
    final players = <String, MatchReplayPlayer>{};
    for (final id in ids) {
      final pa = a.players[id] ?? b.players[id]!;
      final pb = b.players[id] ?? a.players[id]!;
      players[id] = MatchReplayPlayer(
        x: _lerp(pa.x, pb.x, t),
        y: _lerp(pa.y, pb.y, t),
        hasBall: t < .5 ? pa.hasBall : pb.hasBall,
        shirtNumber: t < .5 ? pa.shirtNumber : pb.shirtNumber,
      );
    }
    return MatchReplaySnapshot(
      players: players,
      ballX: _lerp(a.ballX, b.ballX, t),
      ballY: _lerp(a.ballY, b.ballY, t),
      ballHeight: _lerp(a.ballHeight, b.ballHeight, t),
      minute: t < .5 ? a.minute : b.minute,
      homeGoals: t < .5 ? a.homeGoals : b.homeGoals,
      awayGoals: t < .5 ? a.awayGoals : b.awayGoals,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class MatchReplayPlayer {
  const MatchReplayPlayer({
    required this.x,
    required this.y,
    required this.hasBall,
    required this.shirtNumber,
  });

  final double x;
  final double y;
  final bool hasBall;
  final int shirtNumber;
}
