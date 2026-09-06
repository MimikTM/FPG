import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../core/game_engine.dart';
import '../core/game_settings.dart';
import '../core/audio_service.dart';
import '../models/fixture.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../models/match_2d.dart';
import '../simulation/match_2d_engine.dart';
import '../simulation/gameplay_career_integration.dart';
import '../simulation/mini_game_engine.dart';
import '../graphics/pitch_game.dart';
import '../graphics/match_presentation_director.dart';
import '../graphics/matchday_audio_director.dart';
import '../widgets/fpg_animated.dart';

class MatchScreen extends StatefulWidget {
  final GameEngine engine;
  const MatchScreen({super.key, required this.engine});
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with SingleTickerProviderStateMixin {
  late final Match2DEngine _match;
  late final MiniGameEngine _miniGames;
  late final PitchGame _pitchGame;
  Timer? _timer;
  Timer? _introTimer;
  Timer? _lineupTimer;
  Timer? _halftimeTimer;
  Timer? _postMatchTimer;
  Match2DState? _state;
  Match2DEvent? _lastEvent;
  MiniGameDefinition? _pendingMiniGame;
  bool _started = false;
  bool _introActive = false;
  bool _lineupActive = false;
  double _lineupProgress = 0;
  double _introProgress = 0;
  int _introStage = 0;
  bool _paused = false;
  bool _halftimeOverlay = false;
  bool _halftimePresentation = false;
  double _halftimeProgress = 0;
  final List<String> _eventFeed = <String>[];
  final MatchPresentationDirector _presentationDirector = MatchPresentationDirector();
  final MatchdayAudioDirector _audioDirector = MatchdayAudioDirector();

  // Official result for replayed fixtures. For an unplayed interactive
  // fixture, the 2D gameplay result becomes the official MatchResult.
  MatchResult? _officialResult;
  Fixture? _fixture;
  bool _fixtureWasAlreadyPlayed = false;
  String _homeName = 'GOSPODARZE';
  String _awayName = 'GOŚCIE';

  @override
  void initState() {
    super.initState();
    _match = Match2DEngine();
    _presentationDirector.reset();
    _audioDirector.reset();
    _miniGames = MiniGameEngine();
    _pitchGame = PitchGame(getState: () => _state, kitColorFor: _kitColorForGame, presentationDirector: _presentationDirector);
    FPGAudio.playMusic(FPGAudio.matchMusic);
    _start();
  }

  // Mirrors _PitchPainter._kitColorForTeam below, just exposed as a plain
  // callback so PitchGame (a separate presentation-only file) can ask for
  // a team's kit color without needing to know about Match2DState internals.
  Color _kitColorForGame(Match2DTeam team) {
    final s = _state;
    if (s == null) return team == Match2DTeam.home ? Colors.blueAccent : Colors.orangeAccent;
    final ids = s.players.where((p) => p.team == team).map((p) => p.id).toList();
    if (ids.isEmpty) return team == Match2DTeam.home ? Colors.blueAccent : Colors.orangeAccent;
    return _kitColor(ids.first);
  }

  Fixture? _findTodayFixtureForClub(String? clubId, {bool includePlayed = false}) {
    final s = widget.engine.state;
    for (final f in widget.engine.fixtures) {
      if (f.played && !includePlayed) continue;
      if (f.year != s.year || f.month != s.month || f.day != s.day) continue;
      if (clubId == null) return f;
      if (f.homeClubId == clubId || f.awayClubId == clubId) return f;
    }
    return null;
  }

  void _start() {
    final engine = widget.engine;
    final career = engine.careerPlayer;
    final clubId = career?.clubId;

    final fixture = _findTodayFixtureForClub(clubId);
    final alreadyPlayed = _findTodayFixtureForClub(clubId, includePlayed: true);
    _fixture = fixture ?? alreadyPlayed;
    _fixtureWasAlreadyPlayed = fixture == null && alreadyPlayed != null;

    String homeClubId;
    String awayClubId;

    if (fixture != null) {
      homeClubId = fixture.homeClubId;
      awayClubId = fixture.awayClubId;
      if (_fixtureWasAlreadyPlayed) {
        // DailySimulationCore may have already resolved today's official
        // fixture. The match screen is then a presentation/replay layer and
        // MUST NOT simulate the same fixture a second time.
        _officialResult = MatchResult(
          homeClubId: fixture.homeClubId,
          awayClubId: fixture.awayClubId,
          homeGoals: fixture.homeGoals ?? 0,
          awayGoals: fixture.awayGoals ?? 0,
        );
      } else {
        // Preview only: the fixture stays unplayed until the interactive
        // match finishes. The final 2D score is the transaction that updates
        // the table and career statistics.
        _officialResult = engine.previewFixture(fixture);
      }
    } else {
      // Brak meczu ligowego oznacza dzień bez meczu. Nie tworzymy już
      // sztucznego sparingu tylko po to, żeby ekran miał co pokazać.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dzisiaj nie masz zaplanowanego meczu.')),
        );
        Navigator.pop(context);
      });
      return;
    }

    final homeClub = engine.clubs.firstWhere((c) => c.id == homeClubId, orElse: () => engine.clubs.first);
    final awayClub = engine.clubs.firstWhere((c) => c.id == awayClubId, orElse: () => engine.clubs.last);
    _homeName = homeClub.name;
    _awayName = awayClub.name;

    final homePlayers = engine.players.where((p) => p.clubId == homeClubId).toList();
    final awayPlayers = engine.players.where((p) => p.clubId == awayClubId).toList();

    final state = _match.create(
      home: homePlayers.isNotEmpty ? homePlayers : engine.players,
      away: awayPlayers.isNotEmpty ? awayPlayers : engine.players,
      // Phase 6 / 80: an unplayed interactive fixture is now generated by
      // gameplay itself. The old preview score is retained only for replay
      // presentation of fixtures that were already completed elsewhere.
      targetHomeGoals: _fixtureWasAlreadyPlayed ? _officialResult?.homeGoals : null,
      targetAwayGoals: _fixtureWasAlreadyPlayed ? _officialResult?.awayGoals : null,
      gameplayResultAuthority: !_fixtureWasAlreadyPlayed,
      controlledPlayerId: career?.id,
      homeManagerStyle: homeClub.managerStyle,
      awayManagerStyle: awayClub.managerStyle,
    );
    _state = state;
    // Phase 5.45: the official match clock does not start until the broadcast
    // intro finishes. This makes the presentation a real matchday sequence
    // instead of a static card placed on top of gameplay.
    _beginMatchIntro();
  }

  void _beginMatchIntro() {
    _presentationDirector.beginIntro();
    _audioDirector.beginIntro();
    _introTimer?.cancel();
    _lineupTimer?.cancel();
    _introActive = true;
    _introProgress = 0;
    _introStage = 0;
    _paused = true;
    setState(() {});
    _introTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = min(1.0, _introProgress + 0.08 / 4.8);
      final stage = next < .22 ? 0 : next < .48 ? 1 : next < .72 ? 2 : next < .9 ? 3 : 4;
      setState(() {
        _introProgress = next;
        _introStage = stage;
      });
      if (next >= 1.0) {
        timer.cancel();
        _finishMatchIntro();
      }
    });
  }

  void _finishMatchIntro() {
    if (!mounted) return;
    _presentationDirector.beginLineup();
    _audioDirector.beginLineup();
    setState(() {
      _introActive = false;
      _lineupActive = true;
      _lineupProgress = 0;
      _paused = true;
    });
    _lineupTimer?.cancel();
    _lineupTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final next = min(1.0, _lineupProgress + 0.08 / 4.2);
      setState(() => _lineupProgress = next);
      if (next >= 1.0) {
        timer.cancel();
        _finishLineupPresentation();
      }
    });
  }

  void _finishLineupPresentation() {
    if (!mounted) return;
    _presentationDirector.beginLive();
    _audioDirector.beginLive();
    setState(() {
      _lineupActive = false;
      _paused = false;
      _started = true;
    });
    FPGAudio.playSfx(FPGAudio.countdown);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) => _tick());
  }

  List<Match2DPlayer> _lineupFor(Match2DTeam team) {
    final players = (_state?.players ?? const <Match2DPlayer>[])
        .where((p) => p.team == team && p.active)
        .toList();
    players.sort((a, b) {
      int rank(PlayerPosition p) {
        switch (p) {
          case PlayerPosition.goalkeeper: return 0;
          case PlayerPosition.defender: return 1;
          case PlayerPosition.midfielder: return 2;
          case PlayerPosition.winger: return 3;
          case PlayerPosition.striker: return 4;
        }
      }
      final r = rank(a.position).compareTo(rank(b.position));
      return r != 0 ? r : a.shirtNumber.compareTo(b.shirtNumber);
    });
    return players.take(11).toList();
  }

  String _positionLabel(PlayerPosition p) {
    switch (p) {
      case PlayerPosition.goalkeeper: return 'GK';
      case PlayerPosition.defender: return 'DEF';
      case PlayerPosition.midfielder: return 'MID';
      case PlayerPosition.winger: return 'W';
      case PlayerPosition.striker: return 'ST';
    }
  }

  Future<void> _tick() async {
    if (!mounted || _state == null || _paused) return;
    _audioDirector.update(0.06);
    final step = _match.tick();
    if (step.event != null) {
      final e = step.event!;
      _presentationDirector.onEvent(e);
      _audioDirector.onEvent(e);
      final line = '${e.minute}\'  ${e.description}';
      _eventFeed.insert(0, line);
      if (e.type == Match2DEventType.goal) {
        FPGAudio.playSfx(FPGAudio.goal);
        FPGAudio.playSfx(FPGAudio.crowd);
        _pitchGame.celebrateGoal();
      } else if (e.type == Match2DEventType.shot || e.type == Match2DEventType.save) {
        FPGAudio.playSfx(FPGAudio.kick);
      } else if (e.type == Match2DEventType.halftime) {
        FPGAudio.playSfx(FPGAudio.countdown);
      }
      if (_eventFeed.length > 8) _eventFeed.removeLast();
    }
    setState(() => _lastEvent = step.event);
    if (step.event?.type == Match2DEventType.halftime && !_halftimePresentation) {
      _beginHalftimePresentation();
    }
    if (step.event?.isKeyMoment == true && !_fixtureWasAlreadyPlayed) {
      _tryOpenMiniGame(step.event!);
    }
    if (_state!.finished) {
      _timer?.cancel();

      // The 2D layer is the authoritative interactive transaction. The
      // daily simulation intentionally stopped before this fixture, so this
      // commit is the first and only league-table mutation for the player's
      // match.
      _presentationDirector.beginFulltime();
      _audioDirector.beginFulltime();
      if (_fixture != null && !_fixtureWasAlreadyPlayed) {
        final careerPlayerId = widget.engine.careerPlayer?.id;
        final careerPerformance = careerPlayerId == null
            ? null
            : _match.performanceForPlayer(careerPlayerId);
        final gameplayResult = GameplayCareerIntegration.toMatchResult(
          engine: _match,
          homeClubId: _fixture!.homeClubId,
          awayClubId: _fixture!.awayClubId,
          playerPerformances: careerPerformance == null
              ? const <PlayerMatchPerformance>[]
              : <PlayerMatchPerformance>[careerPerformance],
        );
        widget.engine.commitGameplayMatchResult(
          fixture: _fixture!,
          result: gameplayResult,
        );
      }
      try {
        widget.engine.finalizeCareerMatchDay();
        // Open Beta: po każdym rozegranym meczu zapisujemy cały świat.
        // Zapis jest atomowy i nadpisuje główny save, zachowując .bak jako
        // awaryjny rollback.
        final saved = await widget.engine.saveWorld();
        if (mounted && !saved) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mecz zakończony, ale autozapis się nie udał.')));
        }
      } catch (_) {
        // The result is already committed. Do not turn a post-match world
        // processing error into a frozen match screen; the next launch can
        // recover the persisted fixture safely.
        await widget.engine.saveWorld();
      }
      // Mecz musi się jawnie "zakończyć" w oczach gracza — inaczej ekran
      // po prostu zamraża się na 90+X' i jedyną opcją jest cofnięcie
      // przyciskiem wstecz, co (przy braku odświeżenia ekranu kariery)
      // sprawiało wrażenie, że ten sam mecz zaczyna się od nowa.
      WidgetsBinding.instance.addPostFrameCallback((_) => _showMatchFinished());
    }
  }

  void _tryOpenMiniGame(Match2DEvent event) {
    final career = widget.engine.careerPlayer;
    if (career == null || event.playerId != career.id) return;
    final games = _miniGames.forPosition(career.position);
    if (games.isEmpty) return;
    final game = _miniGames.definitionFor(event.miniGameType ?? 'shot', career.position);
    if (_pendingMiniGame != null) return;
    setState(() => _pendingMiniGame = game);
    _showMiniGame(game, event);
  }

  void _beginHalftimePresentation() {
    if (!mounted) return;
    _halftimeTimer?.cancel();
    _presentationDirector.beginHalftime();
    _audioDirector.beginHalftime();
    setState(() {
      _halftimeOverlay = true;
      _halftimePresentation = true;
      _halftimeProgress = 0;
      _paused = true;
    });
    _halftimeTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final next = min(1.0, _halftimeProgress + 0.08 / 5.6);
      setState(() => _halftimeProgress = next);
      if (next >= 1.0) {
        timer.cancel();
        _presentationDirector.beginSecondHalf();
        _audioDirector.beginSecondHalf();
        setState(() {
          _halftimeOverlay = false;
          _halftimePresentation = false;
          _paused = false;
        });
      }
    });
  }

  int _tackleCountForPlayer(String playerId) {
    final events = _match.state?.events ?? const <Match2DEvent>[];
    return events.where((e) =>
        e.playerId == playerId &&
        (e.type == Match2DEventType.tackle ||
            e.type == Match2DEventType.interception)).length;
  }

  String _halftimePlayerLine() {
    final careerId = widget.engine.careerPlayer?.id;
    if (careerId == null || _state == null) return 'Wynik i statystyki meczu są gotowe.';
    final perf = _match.performanceForPlayer(careerId);
    if (perf == null) return 'Twój zawodnik nie rozegrał jeszcze wystarczającej liczby minut.';
    return '${perf.rating.toStringAsFixed(1)} OVR • ${perf.shots} strzały • ${perf.successfulDribbles} dryblingów • ${_tackleCountForPlayer(careerId)} odbiorów';
  }

  Future<void> _showMiniGame(MiniGameDefinition game, Match2DEvent originEvent) async {
    final career = widget.engine.careerPlayer;
    if (career == null || !mounted) return;
    // Zatrzymujemy symulację na czas mini-gry, żeby mecz nie "leciał
    // w tle" niezauważenie i gracz nie tracił kontekstu akcji.
    setState(() => _paused = true);
    FPGAudio.playSfx(FPGAudio.countdown);
    final quality = await Navigator.of(context).push<double>(
      PageRouteBuilder<double>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) =>
            _MiniGameDialog(game: game),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(scale: Tween(begin: .985, end: 1.0).animate(curved), child: child),
          );
        },
      ),
    );
    if (!mounted) return;
    final club = widget.engine.clubs.firstWhere(
      (c) => c.id == career.clubId,
      orElse: () => widget.engine.clubs.first,
    );
    final league = widget.engine.leagues.firstWhere(
      (l) => l.id == club.leagueId,
      orElse: () => widget.engine.leagues.first,
    );
    final result = _miniGames.resolve(
      game,
      _worldPlayer(career),
      quality ?? 50,
      leagueLevel: league.level,
    );
    setState(() => _pendingMiniGame = null);
    FPGAudio.playSfx(result.actionExecuted ? FPGAudio.success : FPGAudio.error);

    // Wynik mini-gry realnie wpływa na przebieg akcji na boisku, a nie
    // tylko na tekst w dymku.
    final synthetic = _match.applyMiniGameOutcome(originEvent, result.actionExecuted && result.generatedStatOutcome);
    if (synthetic != null) {
      setState(() => _lastEvent = synthetic);
    }

    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => _MiniGameResultDialog(result: result, synthetic: synthetic),
      );
    }
    if (!mounted) return;
    setState(() => _paused = false);
  }

  Player _worldPlayer(dynamic career) {
    return widget.engine.players.firstWhere(
      (p) => p.id == career.id,
      orElse: () => Player(
        id: career.id, name: career.fullName, age: career.age, position: career.position,
        nationality: career.nationality, overall: career.overall, potential: career.potential,
        pace: career.pace, shooting: career.shooting, passing: career.passing,
        dribbling: career.dribbling, defending: career.defending, physical: career.physical,
        value: 0, weeklyWage: 0,
      ),
    );
  }

  @override
  void dispose() {
    _audioDirector.dispose();
    _timer?.cancel();
    _introTimer?.cancel();
    _halftimeTimer?.cancel();
    _postMatchTimer?.cancel();
    FPGAudio.stopMusic();
    super.dispose();
  }

  bool _finishedDialogShown = false;

  Future<void> _showMatchFinished() async {
    _presentationDirector.beginPostMatch();
    _audioDirector.beginPostMatch();
    if (_finishedDialogShown || !mounted) return;
    _finishedDialogShown = true;
    final s = _state!;
    final stats = s.stats;
    final careerId = widget.engine.careerPlayer?.id;
    final performance = careerId == null ? null : _match.performanceForPlayer(careerId);
    FPGAudio.playSfx(FPGAudio.crowd);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PostMatchPresentation(
        homeName: _homeName,
        awayName: _awayName,
        homeGoals: s.homeGoals,
        awayGoals: s.awayGoals,
        stats: stats,
        performance: performance,
        events: _eventFeed,
        onExit: () {
          Navigator.pop(context);
          Navigator.pop(context, true);
        },
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      backgroundColor: const Color(0xFF07110A),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('MATCH CENTER', style: TextStyle(letterSpacing: .6)),
            if (s != null && !s.finished && _started) ...[
              const SizedBox(width: 10),
              const _LiveDot(),
            ],
          ],
        ),
        backgroundColor: const Color(0xFF07110A),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _scoreBar(s),
                if (_halftimeOverlay && !_halftimePresentation) _halfTimeBanner(),
            // Center luzuje sztywne ograniczenie wysokości z Expanded, dzięki
            // czemu AspectRatio w _Pitch faktycznie liczy proporcje 1.45
            // zamiast wypełniać całą dostępną (pionową) wysokość kolumny —
            // to właśnie powodowało "boisko w złą stronę".
            Expanded(
              child: Center(
                child: s == null ? const CircularProgressIndicator() : _Pitch(game: _pitchGame),
              ),
            ),
            _eventPanel(),
            _matchLegend(s),
            _presentationPhaseStrip(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: s?.finished == true ? null : () => setState(() => _paused = !_paused),
                      icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
                      label: Text(_paused ? 'WZNÓW MECZ' : 'PAUZA'),
                    ),
                  ),
                ],
              ),
            ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                  child: Text(
                    _paused
                        ? 'Mecz wstrzymany — wykonaj akcję, aby kontynuować.'
                        : 'Najważniejsze akcje Twojego zawodnika pojawią się tutaj jako krótkie wyzwania. Wynik akcji wpływa na przebieg spotkania.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (_introActive) _matchIntroOverlay(),
            if (_lineupActive) _lineupPresentationOverlay(),
            if (_halftimePresentation) _halftimePresentationOverlay(),
          ],
        ),
      ),
    );
  }

  String _clockText(Match2DState? s) {
    if (s == null) return "0'";
    if (s.minute <= 90) return "${s.minute}'";
    return "90+${s.minute - 90}'";
  }

  Widget _matchIntroOverlay() {
    final stages = const [
      ('MATCHDAY', 'STADION • ATMOSFERA • TRANSMISJA'),
      ('THE TEAMS', 'GOSPODARZE  VS  GOŚCIE'),
      ('LINEUP', 'ZAWODNICY WCHODZĄ NA MURAWĘ'),
      ('KICKOFF', 'SĘDZIA GOTOWY • MECZ ZA CHWILĘ'),
      ('LIVE', 'TRANSMISJA ROZPOCZĘTA'),
    ];
    final stage = stages[_introStage.clamp(0, stages.length - 1)];
    final showTeams = _introProgress >= .22;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          color: Colors.black.withValues(alpha: .58),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: .97, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Container(
                    key: ValueKey(_introStage),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: .16)),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xE815251C), Color(0xE807100B)],
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 30, spreadRadius: 4),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _LiveDot(small: true),
                            const SizedBox(width: 7),
                            Text(stage.$2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                )),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(stage.$1,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.2,
                            )),
                        const SizedBox(height: 22),
                        if (showTeams)
                          Row(
                            children: [
                              Expanded(
                                child: _introTeamCard(
                                  name: _homeName,
                                  align: CrossAxisAlignment.end,
                                  color: _fixture == null ? Colors.blueAccent : _kitColor(_fixture!.homeClubId),
                                  label: 'HOME',
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Text('VS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white54,
                                      letterSpacing: 1.4,
                                    )),
                              ),
                              Expanded(
                                child: _introTeamCard(
                                  name: _awayName,
                                  align: CrossAxisAlignment.start,
                                  color: _fixture == null ? Colors.orangeAccent : _kitColor(_fixture!.awayClubId),
                                  label: 'AWAY',
                                ),
                              ),
                            ],
                          )
                        else
                          const Icon(Icons.stadium_rounded, size: 54, color: Colors.white70),
                        const SizedBox(height: 22),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value: _introProgress,
                            backgroundColor: Colors.white.withValues(alpha: .08),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _introTeamCard({
    required String name,
    required CrossAxisAlignment align,
    required Color color,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            )),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (align == CrossAxisAlignment.end) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                name,
                textAlign: align == CrossAxisAlignment.end ? TextAlign.right : TextAlign.left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
            ),
            if (align == CrossAxisAlignment.start) ...[
              const SizedBox(width: 7),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _lineupPresentationOverlay() {
    final home = _lineupFor(Match2DTeam.home);
    final away = _lineupFor(Match2DTeam.away);
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withValues(alpha: .78),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820, maxHeight: 650),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xF0192A20), Color(0xF007100B)],
                    ),
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 40, spreadRadius: 8)],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          const _LiveDot(small: true), const SizedBox(width: 7),
                          const Text('OFFICIAL LINEUP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white60)),
                          const Spacer(),
                          Text('${(_lineupProgress * 100).round()}%', style: const TextStyle(fontSize: 9, color: Colors.white38)),
                        ]),
                        const SizedBox(height: 10),
                        const Text('STARTING XI', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Text('ZAWODNICY WYCHODZĄ NA MURAWĘ', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: .45), fontWeight: FontWeight.w800, letterSpacing: 1)),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 360,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _lineupTeamColumn(_homeName, home, _fixture == null ? Colors.blueAccent : _kitColor(_fixture!.homeClubId), true)),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: VerticalDivider(width: 1, color: Colors.white12)),
                              Expanded(child: _lineupTeamColumn(_awayName, away, _fixture == null ? Colors.orangeAccent : _kitColor(_fixture!.awayClubId), false)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(value: _lineupProgress, minHeight: 4, backgroundColor: Colors.white10),
                        ),
                        const SizedBox(height: 7),
                        const Text('KICKOFF PO PREZENTACJI SKŁADÓW', style: TextStyle(fontSize: 8, color: Colors.white38, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineupTeamColumn(String name, List<Match2DPlayer> players, Color color, bool home) {
    return Column(
      crossAxisAlignment: home ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(mainAxisAlignment: home ? MainAxisAlignment.start : MainAxisAlignment.end, children: [
          if (home) Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          if (home) const SizedBox(width: 7),
          Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: home ? TextAlign.left : TextAlign.right, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
          if (!home) const SizedBox(width: 7),
          if (!home) Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ]),
        const SizedBox(height: 9),
        Expanded(
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: players.length,
            itemBuilder: (context, i) {
              final p = players[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: home ? MainAxisAlignment.start : MainAxisAlignment.end,
                  children: [
                    if (home) ...[
                      _shirtNumber(p.shirtNumber, color), const SizedBox(width: 8),
                      Flexible(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 7), Text(_positionLabel(p.position), style: const TextStyle(fontSize: 8, color: Colors.white38, fontWeight: FontWeight.w900)),
                    ] else ...[
                      Text(_positionLabel(p.position), style: const TextStyle(fontSize: 8, color: Colors.white38, fontWeight: FontWeight.w900)), const SizedBox(width: 7),
                      Flexible(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8), _shirtNumber(p.shirtNumber, color),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _shirtNumber(int number, Color color) => Container(
    width: 28, height: 24, alignment: Alignment.center,
    decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withValues(alpha: .45))),
    child: Text('$number', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
  );

  Widget _presentationPhaseStrip() {
    final label = switch (_presentationDirector.phase) {
      MatchPresentationPhase.intro => 'MATCHDAY',
      MatchPresentationPhase.lineup => 'STARTING XI',
      MatchPresentationPhase.live => 'LIVE',
      MatchPresentationPhase.halftime => 'HALF TIME',
      MatchPresentationPhase.secondHalf => '2ND HALF',
      MatchPresentationPhase.fulltime => 'FULL TIME',
      MatchPresentationPhase.postMatch => 'MATCH REPORT',
    };
    final active = _presentationDirector.activeEvent;
    final eventLabel = active == null ? '' : ' • ${active.name.toUpperCase()}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      child: Row(
        children: [
          const _LiveDot(small: true),
          const SizedBox(width: 7),
          Text(label + eventLabel, style: const TextStyle(fontSize: 8, letterSpacing: 1.1, color: Colors.white38, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _scoreBar(Match2DState? s) {
    final homeColor = _fixture != null ? _kitColor(_fixture!.homeClubId) : const Color(0xFF67D9FF);
    final awayColor = _fixture != null ? _kitColor(_fixture!.awayClubId) : const Color(0xFFFF9F5A);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12241A), Color(0xFF0C1712)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _kitDot(homeColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_homeName, style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _AnimatedScore(home: s?.homeGoals ?? 0, away: s?.awayGoals ?? 0),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(child: Text(_awayName, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    _kitDot(awayColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_clockText(s), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: .5)),
          if (s != null && s.stoppageTime > 0)
            Text('DOLICZONY CZAS: +${s.stoppageTime} MIN', style: const TextStyle(color: Colors.white38, fontSize: 9)),
          if (s != null) ...[
            const SizedBox(height: 12),
            _StatCompareRow(label: 'POSIADANIE', homeValue: s.stats.homePossessionPercent.round(), awayValue: (100 - s.stats.homePossessionPercent).round(), homeColor: homeColor, awayColor: awayColor, suffix: '%'),
            _StatCompareRow(label: 'STRZAŁY', homeValue: s.stats.homeShots, awayValue: s.stats.awayShots, homeColor: homeColor, awayColor: awayColor),
            _StatCompareRow(label: 'CELNE', homeValue: s.stats.homeShotsOnTarget, awayValue: s.stats.awayShotsOnTarget, homeColor: homeColor, awayColor: awayColor),
            _StatCompareRow(label: 'ROŻNE', homeValue: s.stats.homeCorners, awayValue: s.stats.awayCorners, homeColor: homeColor, awayColor: awayColor),
          ],
        ],
      ),
    );
  }

  Widget _kitDot(Color color) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: color.withValues(alpha: .7), blurRadius: 6)],
    ),
  );

  Widget _halfTimeBanner() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    child: NeonGlowCard(
      glowColor: const Color(0xFFFFC24B),
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          Icon(Icons.timer_outlined, size: 20, color: Colors.amber),
          SizedBox(width: 10),
          Expanded(child: Text('PRZERWA 45 — zawodnicy schodzą do szatni. Druga połowa za chwilę.', style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    ),
  );

  Widget _halftimePresentationOverlay() {
    final s = _state;
    if (s == null) return const SizedBox.shrink();
    final homePoss = s.stats.homePossessionPercent.round();
    final awayPoss = 100 - homePoss;
    final homeColor = _fixture != null ? _kitColor(_fixture!.homeClubId) : Colors.blueAccent;
    final awayColor = _fixture != null ? _kitColor(_fixture!.awayClubId) : Colors.orangeAccent;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withValues(alpha: .82),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xF01D2A20), Color(0xF007100B)],
                    ),
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 42, spreadRadius: 8)],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          const _LiveDot(small: true), const SizedBox(width: 7),
                          const Text('BROADCAST • HALF TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white60)),
                          const Spacer(),
                          Text('45’', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        ]),
                        const SizedBox(height: 12),
                        const Text('PRZERWA', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: 2.4)),
                        const SizedBox(height: 5),
                        Text('ZAWODNICY SCHODZĄ DO SZATNI', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: .45), fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _halftimeTeamScore(_homeName, s.homeGoals, homeColor, true)),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('—', style: TextStyle(fontSize: 24, color: Colors.white38, fontWeight: FontWeight.w900))),
                            Expanded(child: _halftimeTeamScore(_awayName, s.awayGoals, awayColor, false)),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _halftimeStat('POSIADANIE', homePoss, awayPoss, homeColor, awayColor, '%'),
                        _halftimeStat('STRZAŁY', s.stats.homeShots, s.stats.awayShots, homeColor, awayColor, ''),
                        _halftimeStat('CELNE', s.stats.homeShotsOnTarget, s.stats.awayShotsOnTarget, homeColor, awayColor, ''),
                        _halftimeStat('ROŻNE', s.stats.homeCorners, s.stats.awayCorners, homeColor, awayColor, ''),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .045), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                          child: Row(children: [
                            const Icon(Icons.person_outline, size: 17, color: Colors.white54),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_halftimePlayerLine(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: _halftimeProgress, minHeight: 4, backgroundColor: Colors.white10)),
                        const SizedBox(height: 7),
                        const Text('DRUGA POŁOWA ZA CHWILĘ • TRANSMISJA WRACA NA MURAWĘ', style: TextStyle(fontSize: 8, color: Colors.white38, letterSpacing: 1.0, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _halftimeTeamScore(String name, int goals, Color color, bool home) => Column(
    crossAxisAlignment: home ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (home) Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        if (home) const SizedBox(width: 7),
        Flexible(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: home ? TextAlign.right : TextAlign.left, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))),
        if (!home) const SizedBox(width: 7),
        if (!home) Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      ]),
      const SizedBox(height: 4),
      Text('$goals', style: const TextStyle(fontSize: 35, fontWeight: FontWeight.w900)),
    ],
  );

  Widget _halftimeStat(String label, int home, int away, Color homeColor, Color awayColor, String suffix) {
    final total = max(1, home + away);
    final hp = home / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(children: [
        Row(children: [
          SizedBox(width: 42, child: Text('$home$suffix', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: homeColor))),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: .8)))),
          SizedBox(width: 42, child: Text('$away$suffix', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: awayColor))),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: hp, minHeight: 3, backgroundColor: awayColor.withValues(alpha: .45), valueColor: AlwaysStoppedAnimation<Color>(homeColor))),
      ]),
    );
  }

  Widget _matchLegend(Match2DState? s) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _legend(Icons.swap_horiz, 'Zmiany ${s?.players.where((p) => !p.active).length ?? 0}'),
        _legend(Icons.flag_outlined, 'Rożne ${s?.stats.homeCorners ?? 0}-${s?.stats.awayCorners ?? 0}'),
        _legend(Icons.style_outlined, 'Kartki ${(s?.stats.homeYellowCards ?? 0) + (s?.stats.homeRedCards ?? 0)}-${(s?.stats.awayYellowCards ?? 0) + (s?.stats.awayRedCards ?? 0)}'),
      ],
    ),
  );

  Widget _legend(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 13, color: Colors.white38), const SizedBox(width: 4), Text(text, style: const TextStyle(fontSize: 9, color: Colors.white54))],
  );

  Widget _eventPanel() => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(10, 10, 10, 4),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    decoration: BoxDecoration(
      color: const Color(0xFF111A14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF67D9FF).withValues(alpha: .14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!_paused && _started) const _LiveDot(small: true) else const Icon(Icons.bolt_rounded, size: 14, color: Colors.amber),
            const SizedBox(width: 6),
            const Text('NA ŻYWO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .5)),
            const Spacer(),
            if (_paused) const Text('PAUZA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.amber)),
          ],
        ),
        const SizedBox(height: 5),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(position: Tween(begin: const Offset(0, .18), end: Offset.zero).animate(anim), child: child),
          ),
          child: Text(
            _lastEvent == null ? (_started ? 'Trwa budowanie akcji...' : 'Przygotowanie meczu...') : '${_lastEvent!.minute}\'  ${_lastEvent!.description}',
            key: ValueKey('${_lastEvent?.minute ?? -1}-${_lastEvent?.description ?? ""}'),
            style: const TextStyle(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_eventFeed.length > 1) ...[
          const SizedBox(height: 5),
          SizedBox(
            height: 30,
            child: ListView.builder(
              reverse: true,
              scrollDirection: Axis.horizontal,
              itemCount: _eventFeed.length.clamp(0, 6),
              itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(8)),
                child: Text(_eventFeed[index], style: const TextStyle(fontSize: 9, color: Colors.white60)),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Small pulsing dot used to signal "match in progress" next to the
/// title and the live event feed.
class _LiveDot extends StatefulWidget {
  final bool small;
  const _LiveDot({this.small = false});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.small ? 8.0 : 9.0;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: const Color(0xFFFF6B6B).withValues(alpha: .3 + .5 * _c.value), blurRadius: 6 + 6 * _c.value, spreadRadius: 1 * _c.value)],
        ),
      ),
    );
  }
}

/// Big scoreboard digits — cross-fades + pop-scales whenever a side's
/// goal count changes, instead of just re-painting a new number.
class _AnimatedScore extends StatelessWidget {
  final int home;
  final int away;
  const _AnimatedScore({required this.home, required this.away});

  @override
  Widget build(BuildContext context) {
    Widget digit(int v, Key key) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: Text('$v', key: key, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        digit(home, ValueKey('h$home')),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text(':', style: TextStyle(fontSize: 22, color: Colors.white38, fontWeight: FontWeight.w900))),
        digit(away, ValueKey('a$away')),
      ],
    );
  }
}

/// A single home/away comparison row with a proportional, animated bar
/// split between the two kit colors — the FIFA/FM "match stats" look.
class _StatCompareRow extends StatelessWidget {
  final String label;
  final int homeValue;
  final int awayValue;
  final Color homeColor;
  final Color awayColor;
  final String suffix;

  const _StatCompareRow({
    required this.label,
    required this.homeValue,
    required this.awayValue,
    required this.homeColor,
    required this.awayColor,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final total = homeValue + awayValue;
    final homeFrac = total == 0 ? 0.5 : homeValue / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$homeValue$suffix', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: homeColor)),
              Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.w700, letterSpacing: .4)),
              Text('$awayValue$suffix', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: awayColor)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 5,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: homeFrac),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Row(
                  children: [
                    Expanded(flex: (v * 1000).round().clamp(1, 999000), child: Container(color: homeColor.withValues(alpha: .8))),
                    Container(width: 1.5, color: Colors.black),
                    Expanded(flex: ((1 - v) * 1000).round().clamp(1, 999000), child: Container(color: awayColor.withValues(alpha: .8))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// KOLORY KLUBOWE — deterministyczne na podstawie id klubu, zamiast
// zawsze tego samego niebieskiego/pomarańczowego.
// ==========================================================

const _kitPalette = [
  [Color(0xFFE53935), Color(0xFFFFFFFF)],
  [Color(0xFF1E88E5), Color(0xFFFFEB3B)],
  [Color(0xFF43A047), Color(0xFFFFFFFF)],
  [Color(0xFF212121), Color(0xFFFFFFFF)],
  [Color(0xFF8E24AA), Color(0xFFFFFFFF)],
  [Color(0xFFFB8C00), Color(0xFF212121)],
  [Color(0xFF00838F), Color(0xFFFFFFFF)],
  [Color(0xFFC62828), Color(0xFFFDD835)],
];

Color _kitColor(String clubId) => _kitPalette[clubId.hashCode.abs() % _kitPalette.length][0];

class _Pitch extends StatelessWidget {
  final PitchGame game;
  const _Pitch({required this.game});
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.45,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: GameWidget(game: game),
    ),
  );
}

class _PitchPainter extends CustomPainter {
  final Match2DState state;
  _PitchPainter(this.state);
  @override
  void paint(Canvas canvas, Size size) {
    _paintGrass(canvas, size);
    _paintMarkings(canvas, size);
    _paintPlayers(canvas, size);
    _paintBall(canvas, size);
  }

  void _paintGrass(Canvas canvas, Size size) {
    const light = Color(0xFF2E8B4E);
    const dark = Color(0xFF267A44);
    const stripes = 10;
    final stripeWidth = size.width / stripes;
    for (var i = 0; i < stripes; i++) {
      final paint = Paint()..color = i.isEven ? light : dark;
      canvas.drawRect(Rect.fromLTWH(i * stripeWidth, 0, stripeWidth, size.height), paint);
    }
  }

  void _paintMarkings(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // Obrys boiska.
    canvas.drawRect(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), line);
    // Linia środkowa i okrąg.
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * .14, line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2, Paint()..color = Colors.white);

    // Pole karne + pole bramkowe + punkt karny (lewa i prawa strona).
    for (final left in [true, false]) {
      final penW = size.width * .16;
      final penH = size.height * .62;
      final sixW = size.width * .06;
      final sixH = size.height * .30;
      final x = left ? 0.0 : size.width - penW;
      canvas.drawRect(Rect.fromLTWH(x, (size.height - penH) / 2, penW, penH), line);
      final sixX = left ? 0.0 : size.width - sixW;
      canvas.drawRect(Rect.fromLTWH(sixX, (size.height - sixH) / 2, sixW, sixH), line);
      final spotX = left ? penW * .62 : size.width - penW * .62;
      canvas.drawCircle(Offset(spotX, size.height / 2), 1.8, Paint()..color = Colors.white);
      // Łuk przy polu karnym.
      final arcRect = Rect.fromCircle(center: Offset(spotX, size.height / 2), radius: size.height * .14);
      canvas.drawArc(arcRect, left ? -0.9 : pi - 0.9, 1.8, false, line);
      // Bramka.
      final goalH = size.height * .14;
      final goalX = left ? -3.0 : size.width - 2.0;
      canvas.drawRect(Rect.fromLTWH(goalX, (size.height - goalH) / 2, 5, goalH), line);
    }

    // Narożniki.
    for (final corner in [
      Offset(0, 0), Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height),
    ]) {
      canvas.drawArc(Rect.fromCircle(center: corner, radius: 5), 0, 2 * pi, false, line);
    }
  }

  void _paintPlayers(Canvas canvas, Size size) {
    final homeColor = state.players.isNotEmpty
        ? _kitColorForTeam(Match2DTeam.home)
        : Colors.blueAccent;
    final awayColor = _kitColorForTeam(Match2DTeam.away);

    for (final p in state.players) {
      if (!p.active) continue;
      final color = p.team == Match2DTeam.home ? homeColor : awayColor;
      final isGk = p.position == PlayerPosition.goalkeeper;
      final pos = Offset(p.x / 100 * size.width, p.y / 100 * size.height);

      // Cień pod zawodnikiem.
      canvas.drawOval(
        Rect.fromCenter(center: pos.translate(0, 5), width: 12, height: 5),
        Paint()..color = Colors.black.withValues(alpha: .25),
      );

      if (p.hasBall) {
        canvas.drawCircle(pos, 11, Paint()..color = Colors.white.withValues(alpha: .35));
      }

      final radius = p.hasBall ? 8.5 : 7.0;
      canvas.drawCircle(pos, radius, Paint()..color = isGk ? const Color(0xFFFFC107) : color);
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = Colors.black.withValues(alpha: .55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${p.shirtNumber}',
          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  Color _kitColorForTeam(Match2DTeam team) {
    final ids = state.players.where((p) => p.team == team).map((p) => p.id).toList();
    if (ids.isEmpty) return team == Match2DTeam.home ? Colors.blueAccent : Colors.orangeAccent;
    return _kitColor(ids.first);
  }

  void _paintBall(Canvas canvas, Size size) {
    final pos = Offset(state.ballX / 100 * size.width, state.ballY / 100 * size.height);
    canvas.drawOval(Rect.fromCenter(center: pos.translate(0, 3), width: 8, height: 3), Paint()..color = Colors.black.withValues(alpha: .35));
    canvas.drawCircle(pos, 4.5, Paint()..color = Colors.white);
    canvas.drawCircle(pos, 4.5, Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) => true;
}

// ==========================================================
// MINI-GRY — akcje sytuacyjne, a nie jeden wspólny suwak.
// Każda pozycja ma własny sposób wykonania.
// ==========================================================

class _MiniGameDialog extends StatefulWidget {
  final MiniGameDefinition game;
  const _MiniGameDialog({required this.game});

  @override
  State<_MiniGameDialog> createState() => _MiniGameDialogState();
}

class _MiniGameDialogState extends State<_MiniGameDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _stageTimer;
  double _quality = 0;
  bool _locked = false;
  int _stage = 1;
  int _stageCount = 3;
  double _stageQuality = 0;

  // --- Strzał: przeciąganie = cel + moc, jak w procy — odciągasz palec od
  // bramki, a piłka leci w przeciwną stronę. Dłuższe odciągnięcie = mocniej.
  Offset _shotPull = Offset.zero;
  bool _shotDragging = false;
  late final double _keeperBias;

  // --- Drybling: przeciągasz piłkę w poziomie, żeby ominąć obrońcę, który
  // z opóźnieniem kopiuje twój tor i zbliża się w dół ekranu.
  double _dribbleX = 0; // -1..1
  double _defenderX = 0; // -1..1

  bool get _isDragKind =>
      widget.game.kind == MiniGameKind.shot || widget.game.kind == MiniGameKind.dribble;

  @override
  void initState() {
    super.initState();
    _keeperBias = (Random().nextDouble() * 2 - 1) * 0.55;
    final kind = widget.game.kind;
    _stageCount = kind == MiniGameKind.shot ? 2 : kind == MiniGameKind.dribble ? 3 : 3;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: kind == MiniGameKind.dribble ? 1700 : 1150),
    )..addListener(() {
        if (!mounted || _locked) return;
        if (kind == MiniGameKind.dribble) {
          _defenderX += (_dribbleX - _defenderX) * .10;
        }
        setState(() {});
      });
    if (kind == MiniGameKind.dribble) {
      _controller.repeat();
    } else if (!_isDragKind) {
      _controller.repeat();
    }
    _startStageTimer();
  }

  double get _wave => triangleWave(_controller.value);

  void _startStageTimer() {
    _stageTimer?.cancel();
    final seconds = switch (GameSettings.difficulty) {
      MiniGameDifficulty.easy => 7,
      MiniGameDifficulty.medium => 5,
      MiniGameDifficulty.hard => 3,
      MiniGameDifficulty.simulation => 3,
    };
    _stageTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted || _locked) return;
      _finish(0);
    });
  }

  void _finish(double quality) {
    if (_locked) return;
    final q = quality.clamp(0, 100).toDouble();
    if (_stage < _stageCount) {
      setState(() {
        _stageQuality += q;
        _stage++;
        _shotPull = Offset.zero;
        _shotDragging = false;
        _dribbleX = 0;
        _defenderX = 0;
      });
      _startStageTimer();
      if (!_controller.isAnimating) _controller.repeat();
      return;
    }
    _controller.stop();
    _stageTimer?.cancel();
    setState(() {
      _stageQuality += q;
      _quality = (_stageQuality / _stageCount).clamp(0, 100).toDouble();
      _locked = true;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) Navigator.pop(context, _quality);
    });
  }

  void _tap(TapUpDetails details, Size size) {
    if (_locked) return;
    final p = details.localPosition;

    switch (widget.game.kind) {
      case MiniGameKind.pass:
        final gateX = size.width * (.12 + progressSafe * .76);
        final d = ((p.dx - gateX).abs() * 2.0 + (p.dy - size.height * .52).abs());
        _finish((100 - d * 1.8).clamp(0, 100));
      case MiniGameKind.tackle:
        final target = Offset(
          size.width * (.20 + progressSafe * .60),
          size.height * (.72 - progressSafe * .44),
        );
        _finish((100 - (p - target).distance * 2.2).clamp(0, 100));
      case MiniGameKind.save:
        final ball = Offset(
          size.width * (.18 + ((progressSafe + .18) % 1) * .64),
          size.height * (.26 + ((progressSafe * .73) % 1) * .44),
        );
        _finish((100 - (p - ball).distance * 2.0).clamp(0, 100));
      case MiniGameKind.shot:
      case MiniGameKind.dribble:
        break; // obsłużone przez przeciąganie (patrz _onShot*/_onDribble*).
    }
  }

  double get progressSafe => _wave;

  double _shotMaxPull(Size size) => size.shortestSide * .55;

  void _onShotPanUpdate(DragUpdateDetails d, Size size) {
    if (_locked) return;
    final maxPull = _shotMaxPull(size);
    setState(() {
      _shotDragging = true;
      final next = _shotPull + d.delta;
      final dist = next.distance;
      _shotPull = dist > maxPull ? next * (maxPull / dist) : next;
    });
  }

  void _onShotPanEnd(Size size) {
    if (_locked || !_shotDragging) return;
    final maxPull = _shotMaxPull(size);
    final power = (_shotPull.distance / maxPull).clamp(0.0, 1.0);
    final aim = (-_shotPull.dx / maxPull).clamp(-1.0, 1.0);

    // Najlepsza skuteczność jest w "strefie idealnej" mocy — za słabo i
    // bramkarz łapie bez trudu, za mocno i tracisz kontrolę nad strzałem.
    final powerScore = power < .35
        ? power / .35 * 55
        : power > .92
            ? 100 - (power - .92) / .08 * 60
            : 70 + (1 - (power - .63).abs() / .30) * 30;

    // Celność liczona względem pozycji bramkarza — im dalej od niego (ale
    // wciąż w świetle bramki), tym lepiej.
    final distFromKeeper = (aim - _keeperBias).abs();
    final accuracyScore = aim.abs() <= 1.0 ? (40 + distFromKeeper * 60).clamp(0, 100) : 15.0;

    _finish(powerScore * .45 + accuracyScore * .55);
  }

  void _onDribblePanUpdate(DragUpdateDetails d, Size size) {
    if (_locked) return;
    setState(() {
      _dribbleX = (_dribbleX + d.delta.dx / (size.width * .5)).clamp(-1.0, 1.0);
    });
  }

  void _finishDribble() {
    if (_locked) return;
    final separation = (_dribbleX - _defenderX).abs();
    _finish((separation * 140).clamp(0.0, 100.0));
  }


  @override
  void dispose() {
    _stageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.game.kind;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF07110C),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Przerwij',
                    onPressed: _locked ? null : () => _finish(0),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 4),
                  Icon(_iconFor(kind), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.game.title,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _miniBadge('ETAP $_stage/$_stageCount'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(widget.game.instruction, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _miniBadge(_variantLabel(widget.game.type)),
                      const SizedBox(width: 6),
                      _miniBadge(GameSettings.difficulty.label),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onTapUp: _isDragKind ? null : (details) => _tap(details, size),
                      onPanUpdate: kind == MiniGameKind.shot
                          ? (d) => _onShotPanUpdate(d, size)
                          : kind == MiniGameKind.dribble
                              ? (d) => _onDribblePanUpdate(d, size)
                              : null,
                      onPanEnd: kind == MiniGameKind.shot ? (_) => _onShotPanEnd(size) : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CustomPaint(
                          painter: _ActionPainter(
                            kind: kind,
                            progress: kind == MiniGameKind.dribble ? _controller.value : _wave,
                            locked: _locked,
                            shotPull: _shotPull,
                            keeperBias: _keeperBias,
                            dribbleX: _dribbleX,
                            defenderX: _defenderX,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Column(
                children: [
                  if (!_locked && kind != MiniGameKind.shot && kind != MiniGameKind.dribble)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(value: _wave, minHeight: 6),
                    ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 140),
                    child: Text(
                      _locked
                          ? 'Wynik: ${_quality.round()}/100'
                          : kind == MiniGameKind.shot
                              ? (_shotDragging ? 'PUŚĆ, ABY ODDAĆ STRZAŁ' : 'PRZECIĄGNIJ OD BRAMKI — CEL I MOC')
                              : kind == MiniGameKind.dribble
                                  ? 'PRZECIĄGAJ W LEWO / PRAWO, ABY OMINĄĆ OBROŃCĘ'
                                  : 'DOTKNIJ W ODPOWIEDNIM MOMENCIE',
                      key: ValueKey('${_locked}_${_stage}_${_shotDragging}'),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
  );

  String _variantLabel(MiniGameType type) => switch (type) {
    MiniGameType.goalkeeperSave => 'STRZAŁ',
    MiniGameType.goalkeeperOneOnOne => 'SAM NA SAM',
    MiniGameType.goalkeeperPosition => 'USTAWIENIE',
    MiniGameType.goalkeeperCross => 'DOŚRODKOWANIE',
    MiniGameType.goalkeeperPenalty => 'KARNY',
    MiniGameType.defenderTackle => 'ODBÓR',
    MiniGameType.defenderBlock => 'BLOK',
    MiniGameType.defenderInterception => 'PRZECHWYT',
    MiniGameType.defenderPositioning => 'POZYCJA',
    MiniGameType.defenderClearance => 'WYCZYSZCZENIE',
    MiniGameType.midfielderShortPass => 'KRÓTKIE PODANIE',
    MiniGameType.midfielderThroughBall => 'PROSTOPADŁE',
    MiniGameType.midfielderVision => 'WIZJA',
    MiniGameType.midfielderPress => 'PRESSING',
    MiniGameType.midfielderLongPass => 'DŁUGA PIŁKA',
    MiniGameType.attackerFinish => 'WYKOŃCZENIE',
    MiniGameType.attackerHeader => 'GŁÓWKA',
    MiniGameType.attackerOneTouch => 'PIERWSZY KONTAKT',
    MiniGameType.attackerRunBehind => 'WYJŚCIE ZA LINIĘ',
    MiniGameType.attackerHoldUp => 'GRA TYŁEM',
  };

  String _difficultyLabel(MiniGameType type) {
    final hard = type.index % 3 == 2;
    return hard ? 'WYSOKIE RYZYKO' : type.index % 2 == 0 ? 'NORMALNE' : 'PRESJA';
  }

  IconData _iconFor(MiniGameKind kind) => switch (kind) {
        MiniGameKind.shot => Icons.sports_soccer,
        MiniGameKind.pass => Icons.alt_route,
        MiniGameKind.dribble => Icons.directions_run,
        MiniGameKind.tackle => Icons.shield,
        MiniGameKind.save => Icons.pan_tool,
      };
}

class _ActionPainter extends CustomPainter {
  final MiniGameKind kind;
  final double progress;
  final bool locked;
  final Offset shotPull;
  final double keeperBias;
  final double dribbleX;
  final double defenderX;

  _ActionPainter({
    required this.kind,
    required this.progress,
    required this.locked,
    this.shotPull = Offset.zero,
    this.keeperBias = 0,
    this.dribbleX = 0,
    this.defenderX = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF173C25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(12),
      ),
      bg,
    );

    switch (kind) {
      case MiniGameKind.shot:
        _shot(canvas, size);
      case MiniGameKind.pass:
        _pass(canvas, size);
      case MiniGameKind.dribble:
        _dribble(canvas, size);
      case MiniGameKind.tackle:
        _tackle(canvas, size);
      case MiniGameKind.save:
        _save(canvas, size);
    }
  }

  void _shot(Canvas c, Size s) {
    final goal = Rect.fromLTWH(s.width * .12, s.height * .08, s.width * .76, s.height * .30);
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    c.drawRect(goal, line);

    // Bramkarz — celuj z dala od niego.
    final keeperX = goal.left + goal.width * (0.5 + keeperBias * .5);
    c.drawCircle(Offset(keeperX, goal.center.dy), 10, Paint()..color = const Color(0xFFFFC107));

    final ballOrigin = Offset(s.width * .5, s.height * .84);
    final maxPull = s.shortestSide * .55;
    final aimVector = -shotPull;
    final power = (shotPull.distance / maxPull).clamp(0.0, 1.0);
    final target = Offset(
      (ballOrigin.dx + aimVector.dx).clamp(0.0, s.width),
      (ballOrigin.dy + aimVector.dy).clamp(0.0, s.height),
    );

    if (shotPull.distance > 1) {
      final arrow = Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      c.drawLine(ballOrigin, target, arrow);
      c.drawCircle(target, 5, Paint()..color = Colors.redAccent);

      final barRect = Rect.fromLTWH(s.width * .04, s.height * .40, 9, s.height * .48);
      c.drawRect(barRect, Paint()..color = Colors.white24);
      final fillH = barRect.height * power;
      c.drawRect(
        Rect.fromLTWH(barRect.left, barRect.bottom - fillH, barRect.width, fillH),
        Paint()..color = power > .85 ? Colors.orangeAccent : Colors.greenAccent,
      );
    }

    _ball(c, ballOrigin, 9);
    _text(c, 'ODCIĄGNIJ I PUŚĆ', Offset(s.width * .26, s.height * .58));
  }

  void _pass(Canvas c, Size s) {
    final y = s.height * .52;
    final start = Offset(s.width * .12, y);
    final end = Offset(s.width * .88, y);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .45)
      ..strokeWidth = 3;
    c.drawLine(start, end, line);

    final gateX = s.width * (.12 + progress * .76);
    c.drawRect(
      Rect.fromCenter(center: Offset(gateX, y), width: 34, height: 70),
      Paint()..color = Colors.white.withValues(alpha: .85),
    );
    c.drawRect(
      Rect.fromCenter(center: Offset(gateX, y), width: 20, height: 52),
      Paint()..color = const Color(0xFF173C25),
    );

    _ball(c, start, 8);
    _text(c, 'OKNO PODANIA', Offset(s.width * .30, s.height * .18));
  }

  void _dribble(Canvas c, Size s) {
    double xFor(double t) => s.width * (.5 + t * .38);
    final laneY = s.height * .74;
    final defStartY = s.height * .22;

    c.drawLine(
      Offset(xFor(-1), laneY),
      Offset(xFor(1), laneY),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 2,
    );

    final defY = defStartY + (laneY - defStartY) * progress;
    c.drawCircle(
      Offset(xFor(defenderX), defY),
      14,
      Paint()..color = Colors.redAccent.withValues(alpha: .85),
    );
    _ball(c, Offset(xFor(dribbleX), laneY), 9);
    _text(c, 'OMIŃ OBROŃCĘ', Offset(s.width * .30, s.height * .06));
  }

  void _tackle(Canvas c, Size s) {
    final duelX = s.width * (.20 + progress * .60);
    c.drawLine(
      Offset(s.width * .10, s.height * .72),
      Offset(s.width * .90, s.height * .28),
      Paint()
        ..color = Colors.white.withValues(alpha: .25)
        ..strokeWidth = 4,
    );
    c.drawCircle(
      Offset(duelX, s.height * (.72 - progress * .44)),
      28,
      Paint()..color = Colors.white.withValues(alpha: .18),
    );
    _ball(c, Offset(duelX, s.height * (.72 - progress * .44)), 8);
    _text(c, 'WEJDŹ W POJEDYNEK', Offset(s.width * .28, s.height * .08));
  }

  void _save(Canvas c, Size s) {
    final goal = Rect.fromLTWH(s.width * .10, s.height * .20, s.width * .80, s.height * .56);
    c.drawRect(
      goal,
      Paint()
        ..color = Colors.white.withValues(alpha: .75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final ballX = s.width * (.18 + ((progress + .18) % 1) * .64);
    final ballY = s.height * (.26 + ((progress * .73) % 1) * .44);
    final keeperX = s.width * (.18 + progress * .64);
    c.drawCircle(
      Offset(keeperX, s.height * .72),
      20,
      Paint()..color = const Color(0xFFFFC107),
    );
    _ball(c, Offset(ballX, ballY), 9);
    _text(c, 'OBROŃ', Offset(s.width * .40, s.height * .08));
  }

  void _ball(Canvas c, Offset p, double r) {
    c.drawCircle(p, r, Paint()..color = Colors.white);
    c.drawCircle(
      p,
      r,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _text(Canvas c, String text, Offset position) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, position);
  }

  @override
  bool shouldRepaint(covariant _ActionPainter oldDelegate) => true;
}


class _PostMatchPresentation extends StatelessWidget {
  final String homeName;
  final String awayName;
  final int homeGoals;
  final int awayGoals;
  final Match2DStats stats;
  final PlayerMatchPerformance? performance;
  final List<String> events;
  final VoidCallback onExit;

  const _PostMatchPresentation({
    required this.homeName,
    required this.awayName,
    required this.homeGoals,
    required this.awayGoals,
    required this.stats,
    required this.performance,
    required this.events,
    required this.onExit,
  });

  String _winnerLabel() {
    if (homeGoals == awayGoals) return 'REMIS';
    return homeGoals > awayGoals ? 'ZWYCIĘSTWO GOSPODARZY' : 'ZWYCIĘSTWO GOŚCI';
  }

  Widget _stat(String label, String home, String away) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 54, child: Text(home, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
            Expanded(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800))),
            SizedBox(width: 54, child: Text(away, style: const TextStyle(fontWeight: FontWeight.w900))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final homePoss = stats.homePossessionPercent.round();
    final awayPoss = stats.awayPossessionPercent.round();
    return Dialog(
      backgroundColor: const Color(0xFF0B1710),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('FULL TIME', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, letterSpacing: 2.2, color: Colors.white60, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(_winnerLabel(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Text(homeName, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('$homeGoals : $awayGoals', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
                  Expanded(child: Text(awayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: 18),
              const Text('MATCH REPORT', style: TextStyle(letterSpacing: 1.4, fontSize: 11, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              _stat('POSIADANIE', '$homePoss%', '$awayPoss%'),
              _stat('STRZAŁY', '${stats.homeShots}', '${stats.awayShots}'),
              _stat('CELNE', '${stats.homeShotsOnTarget}', '${stats.awayShotsOnTarget}'),
              _stat('PODANIA', '${stats.homeCompletedPasses}/${stats.homePasses}', '${stats.awayCompletedPasses}/${stats.awayPasses}'),
              _stat('ROŻNE', '${stats.homeCorners}', '${stats.awayCorners}'),
              _stat('FAULE', '${stats.homeFouls}', '${stats.awayFouls}'),
              _stat('ŻÓŁTE', '${stats.homeYellowCards}', '${stats.awayYellowCards}'),
              _stat('CZERWONE', '${stats.homeRedCards}', '${stats.awayRedCards}'),
              if (performance != null) ...[
                const SizedBox(height: 16),
                const Text('YOUR PERFORMANCE', style: TextStyle(letterSpacing: 1.4, fontSize: 11, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _metric('${performance!.rating.toStringAsFixed(1)}', 'RATING')),
                    Expanded(child: _metric('${performance!.minutes}’', 'MINUTY')),
                    Expanded(child: _metric('${performance!.goals}', 'GOLE')),
                    Expanded(child: _metric('${performance!.shots}', 'STRZAŁY')),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${performance!.keyPasses} klucz. podań • ${performance!.successfulDribbles} udanych dryblingów • ${performance!.yellowCards} żółte • ${performance!.redCards} czerwone', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
              if (events.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('KEY MOMENTS', style: TextStyle(letterSpacing: 1.4, fontSize: 11, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                ...events.take(6).map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(e, style: const TextStyle(fontSize: 10, color: Colors.white70)))),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: onExit, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('ZAKOŃCZ PREZENTACJĘ')),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _metric(String value, String label) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.white54, fontWeight: FontWeight.w800)),
        ],
      );
}

class _MiniGameResultDialog extends StatelessWidget {
  final MiniGameResult result;
  final Match2DEvent? synthetic;

  const _MiniGameResultDialog({
    required this.result,
    required this.synthetic,
  });

  @override
  Widget build(BuildContext context) {
    final scored = synthetic?.type == Match2DEventType.goal;
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            scored
                ? Icons.sports_soccer
                : (result.actionExecuted
                    ? Icons.check_circle
                    : Icons.cancel),
            color: scored
                ? Colors.green
                : (result.actionExecuted
                    ? Colors.blueAccent
                    : Colors.redAccent),
          ),
          const SizedBox(width: 8),
          Text(
            scored
                ? 'GOL!'
                : (result.actionExecuted
                    ? 'AKCJA UDANA'
                    : 'AKCJA NIEUDANA'),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Wykonanie: ${result.executionScore.round()}/100'),
          const SizedBox(height: 6),
          Text(synthetic?.description ?? result.message),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('WRÓĆ DO MECZU'),
        ),
      ],
    );
  }
}
