import 'dart:math';
import 'dart:async';

import '../data/world_data.dart';

import '../models/club.dart';
import '../models/fixture.dart';
import '../models/league.dart';
import '../models/match_result.dart';
import '../models/match_2d.dart';
import '../models/player.dart';
import '../models/player_career.dart';
import '../models/player_contract.dart';

import '../simulation/fixture_generator.dart';
import '../simulation/league_engine.dart';
import '../simulation/match_engine.dart';
import '../simulation/world_engine.dart';
import '../simulation/career_world_bridge.dart';
import '../simulation/world_player_generator.dart';
import '../simulation/world_integrity_validator.dart';
import '../simulation/market_value_engine.dart';
import '../simulation/career_match_rating_engine.dart';

import 'game_state.dart';
import 'game_settings.dart';
import 'daily_simulation_core.dart';
import 'training_engine.dart';
import '../database/world_save.dart';

class GameEngine {
  final GameState state;

  late final List<League> leagues;
  late final List<Club> clubs;
  late final List<Player> players;

  late LeagueEngine leagueEngine;
  late final MatchEngine matchEngine;
  late final WorldEngine worldEngine;

  /// Mutable because SAVE/LOAD must restore the exact season fixture list.
  /// A `late final` list could only mutate its contents; replacing the season
  /// schedule after loading a different season would otherwise be unsafe.
  final List<Fixture> fixtures = <Fixture>[];

  final TrainingEngine trainingEngine = TrainingEngine();
  late final DailySimulationCore dailySimulationCore;
  final CareerWorldBridge careerWorldBridge = CareerWorldBridge();

  final Random _random = Random();
  final MarketValueEngine marketValueEngine = MarketValueEngine();
  late final CareerMatchRatingEngine careerMatchRatingEngine;

  // Idempotency guard: one fixture may update career statistics only once.
  final Set<String> _processedCareerFixtureKeys = <String>{};

  // P2.2-A — one meaningful career action per simulation day.
  bool _dailyCareerActionConsumed = false;
  String? _dailyCareerAction;
  int _dailyCareerActionDay = -1;

  /// Daily actions belong to the simulation calendar, never to the Flutter
  /// screen lifecycle. This fixes the classic bug where training stayed
  /// locked after advancing a day or became unlocked on the wrong day.
  bool get dailyCareerActionConsumed =>
      _dailyCareerActionDay == currentAbsoluteDay && _dailyCareerActionConsumed;
  String? get dailyCareerAction =>
      dailyCareerActionConsumed ? _dailyCareerAction : null;
  DailySimulationReport? get lastDailyReport => dailySimulationCore.lastReport;

  PlayerCareer? careerPlayer;

  // V19.9 — snapshot of the player's real match for the post-match world bridge.
  bool _careerMatchToday = false;
  bool _careerMatchAppeared = false;
  bool _careerMatchStarted = false;
  int _careerMatchMinutes = 0;
  int _careerMatchGoals = 0;
  int _careerMatchAssists = 0;
  double _careerMatchRating = 6.0;
  int _careerMatchHomeGoals = 0;
  int _careerMatchAwayGoals = 0;
  String? _careerMatchClubId;
  bool _careerMatchClubIsHome = false;
  String? _careerMatchFixtureKey;

  // career_home_screen.dart wywołuje `engine.gameState` (SaveManager),
  // a jedyne pole nazywało się `state` — alias, żeby nie trzeba było
  // przerabiać ekranu ani łamać reszty kodu, który używa `state`.
  GameState get gameState => state;

  /// Gwarantuje, że każdy klub ma pełną kadrę (min. 16 zawodników), zanim
  /// jakikolwiek mecz (2D albo symulowany) spróbuje z niej korzystać.
  /// WorldData dostarcza tylko garstkę testowych piłkarzy — reszta kadry
  /// jest generowana raz, przy starcie nowej gry.
  void _ensureFullSquads() {
    final generator = WorldPlayerGenerator(random: _random);
    for (final club in clubs) {
      final current = players.where((p) => p.clubId == club.id).length;
      if (current >= 16) continue;
      players.addAll(
        generator.generateFirstTeamSquad(
          year: state.year,
          club: club,
          targetSize: 20 - current,
        ),
      );
    }
  }

  /// Rebuilds the reverse roster index from the authoritative Player.clubId
  /// values. This is intentionally local to GameEngine so it can be called
  /// before WorldEngine is initialized.
  void _syncClubRosters() {
    for (final club in clubs) {
      club.playerIds.clear();
    }

    _ensureSquadNumbers();

    final clubsById = <String, Club>{
      for (final club in clubs) club.id: club,
    };

    for (final player in players) {
      final clubId = player.clubId;
      if (clubId == null || clubId.isEmpty) continue;

      final club = clubsById[clubId];
      if (club != null) {
        club.addPlayer(player.id);
      }
    }
  }

  /// Każdy zawodnik ma stały, unikalny numer w obrębie klubu. Starsze
  /// zapisy nie miały tego pola, dlatego brakujące/duplikaty są naprawiane
  /// deterministycznie przy uruchomieniu i po wczytaniu zapisu.
  void _ensureSquadNumbers() {
    for (final club in clubs) {
      final squad = players.where((p) => p.clubId == club.id).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      final used = <int>{};
      for (final player in squad) {
        final current = player.shirtNumber;
        if (current >= 1 && current <= 99 && !used.contains(current)) {
          used.add(current);
          continue;
        }
        for (var number = 1; number <= 99; number++) {
          if (!used.contains(number)) {
            player.shirtNumber = number;
            used.add(number);
            break;
          }
        }
      }
    }
  }

  // ==========================================================
  // KONSTRUKTOR
  // ==========================================================

  GameEngine({
    GameState? state,
  }) : state = state ?? GameState() {
    dailySimulationCore = DailySimulationCore(state: this.state);

    // WorldData is the immutable-ish seed for a NEW career. Its objects are
    // mutable at runtime (promotions, budgets, managers, rosters, etc.), so
    // keeping direct references here leaks one career into another career
    // and also makes Flutter tests order-dependent. Build a deep runtime copy
    // for every GameEngine instance.
    leagues = WorldData.leagues
        .map((league) => League(
              id: league.id,
              name: league.name,
              country: league.country,
              level: league.level,
            ))
        .toList();
    clubs = WorldData.clubs
        .map((club) => Club.fromJson(club.toJson()))
        .toList();
    // WorldData.players contains seed records, but Player is mutable too
    // (contracts, transfers, form, injuries, development). Deep-copy them so
    // a previous GameEngine can never contaminate a fresh career.
    players = WorldData.players
        .map((player) => Player.fromJson(player.toJson()))
        .toList();
    _ensureFullSquads();
    // Keep the roster index and Player.clubId authoritative from the moment a
    // new engine is created. SAVE/LOAD and integrity validation both rely on
    // these two views describing the same ownership graph.
    _syncClubRosters();

    final leagueClubs = clubs.where((club) => club.leagueId == 'pol_ek').toList();
    leagueEngine = LeagueEngine(clubs: leagueClubs);

    matchEngine = MatchEngine();
    careerMatchRatingEngine = CareerMatchRatingEngine(random: _random);

    worldEngine = WorldEngine(
      clubs: clubs,
      players: players,
      leagues: leagues,
      seasonStartYear: this.state.season,
    );

    fixtures.addAll(FixtureGenerator.generateSeasonFixtures(
      leagueClubs,
      seasonStartYear: this.state.season,
    ));

    // A new career starts at the season start on the simulation calendar.
    // Never simulate fixtures before the player's simulation start date.
    // The world simulation may catch up its background events, but the
    // player's league must not gain phantom results or points.
    worldEngine.catchUpToDate(
      year: this.state.year,
      month: this.state.month,
      day: this.state.day,
    );
  }

  void _catchUpCareerLeague() {
    final currentDate = DateTime(state.year, state.month, state.day);
    for (final fixture in fixtures) {
      if (fixture.played) continue;
      final fixtureDate = DateTime(fixture.year, fixture.month, fixture.day);
      if (fixtureDate.isAfter(currentDate)) continue;
      playFixture(fixture);
    }
  }

  // ==========================================================
  // TWORZENIE ZAWODNIKA
  // ==========================================================

  int _potentialForStartingOverall(int overall) {
    // Higher starting OVR is a shorter route to first-team football, but
    // deliberately leaves less room for long-term growth.
    switch (overall) {
      case 40:
        return 90;
      case 45:
        return 88;
      case 50:
        return 86;
      case 55:
        return 84;
      case 60:
        return 82;
      case 65:
        return 80;
      case 70:
        return 78;
      default:
        return (92 - overall ~/ 2).clamp(75, 92).toInt();
    }
  }

  void createPlayer({
    required String firstName,
    required String lastName,
    required String nationality,
    required int age,
    required int height,
    required PlayerPosition position,
    required int pace,
    required int shooting,
    required int passing,
    required int dribbling,
    required int defending,
    required int physical,
    int initialOverall = 60,
  }) {
    final selectedOverall = initialOverall.clamp(40, 70).toInt();
    final player = PlayerCareer(
      id: 'career_player_001',
      firstName: firstName,
      lastName: lastName,
      nationality: nationality,
      age: age,
      height: height,
      position: position,
      overall: selectedOverall,
      potential: _potentialForStartingOverall(selectedOverall),
      pace: pace,
      shooting: shooting,
      passing: passing,
      dribbling: dribbling,
      defending: defending,
      physical: physical,
    );

    player.refreshOverall();

    careerPlayer = player;
    careerWorldBridge.attach(career: player, worldPlayers: players, clubs: clubs);
    careerWorldBridge.pushCareerState(player);
    marketValueEngine.refreshCareerPlayer(player);
  }

  // ==========================================================
  // PEŁNY ZAPIS / ODCZYT OFFLINE
  // ==========================================================

  /// Serializable snapshot of the career-match transaction state.
  /// This is intentionally kept in GameEngine because it represents transient
  /// state that is not part of PlayerCareer itself.
  Map<String, dynamic> get careerMatchSnapshot => {
    'today': _careerMatchToday,
    'appeared': _careerMatchAppeared,
    'started': _careerMatchStarted,
    'minutes': _careerMatchMinutes,
    'goals': _careerMatchGoals,
    'assists': _careerMatchAssists,
    'rating': _careerMatchRating,
    'homeGoals': _careerMatchHomeGoals,
    'awayGoals': _careerMatchAwayGoals,
    'clubId': _careerMatchClubId,
    'clubIsHome': _careerMatchClubIsHome,
    'fixtureKey': _careerMatchFixtureKey,
    'processedFixtureKeys': _processedCareerFixtureKeys.toList(),
    'dailyCareerActionConsumed': _dailyCareerActionConsumed,
    'dailyCareerAction': _dailyCareerAction,
    'dailyCareerActionDay': _dailyCareerActionDay,
  };

  void _restoreCareerMatchSnapshot(dynamic raw) {
    if (raw is! Map) return;
    final m = Map<String, dynamic>.from(raw);
    _careerMatchToday = m['today'] == true;
    _careerMatchAppeared = m['appeared'] == true;
    _careerMatchStarted = m['started'] == true;
    _careerMatchMinutes = (m['minutes'] as num?)?.toInt() ?? 0;
    _careerMatchGoals = (m['goals'] as num?)?.toInt() ?? 0;
    _careerMatchAssists = (m['assists'] as num?)?.toInt() ?? 0;
    _careerMatchRating = (m['rating'] as num?)?.toDouble() ?? 6.0;
    _careerMatchHomeGoals = (m['homeGoals'] as num?)?.toInt() ?? 0;
    _careerMatchAwayGoals = (m['awayGoals'] as num?)?.toInt() ?? 0;
    _careerMatchClubId = m['clubId'] as String?;
    _careerMatchClubIsHome = m['clubIsHome'] == true;
    _careerMatchFixtureKey = m['fixtureKey'] as String?;
    _processedCareerFixtureKeys
      ..clear()
      ..addAll((m['processedFixtureKeys'] is List)
          ? (m['processedFixtureKeys'] as List).whereType<String>()
          : const <String>[]);
    _dailyCareerActionConsumed = m['dailyCareerActionConsumed'] == true;
    _dailyCareerAction = m['dailyCareerAction'] as String?;
    _dailyCareerActionDay = (m['dailyCareerActionDay'] as num?)?.toInt() ??
        (_dailyCareerActionConsumed ? currentAbsoluteDay : -1);
  }

  Future<bool> saveWorld() => WorldSave.save(this);

  Future<bool> loadWorld() async {
    final snapshot = await WorldSave.load();
    if (snapshot == null) return false;

    // V25.1 RC: LOAD is a transaction. Build and validate every mutable
    // collection from the snapshot BEFORE touching the live engine. The old
    // implementation restored state/players/clubs first and only then ran
    // WorldIntegrityValidator, which meant a corrupt save could leave the
    // current career half-restored even though loadWorld() returned false.
    final candidatePlayers = <Player>[];
    final rawPlayersPreflight = snapshot['players'];
    if (rawPlayersPreflight is List) {
      for (final raw in rawPlayersPreflight) {
        if (raw is! Map) return false;
        try {
          candidatePlayers.add(
            Player.fromJson(Map<String, dynamic>.from(raw)),
          );
        } catch (_) {
          return false;
        }
      }
      if (candidatePlayers.isEmpty) return false;
    } else if (rawPlayersPreflight != null) {
      return false;
    } else {
      candidatePlayers.addAll(
        players.map((player) => Player.fromJson(player.toJson())),
      );
    }

    final candidateClubs = <Club>[];
    final rawClubsPreflight = snapshot['clubs'];
    if (rawClubsPreflight is List) {
      for (final raw in rawClubsPreflight) {
        if (raw is! Map) return false;
        try {
          candidateClubs.add(
            Club.fromJson(Map<String, dynamic>.from(raw)),
          );
        } catch (_) {
          return false;
        }
      }
      if (candidateClubs.isEmpty) return false;
    } else if (rawClubsPreflight != null) {
      return false;
    } else {
      candidateClubs.addAll(
        clubs.map((club) => Club.fromJson(club.toJson())),
      );
    }

    final candidateIntegrity = WorldIntegrityValidator.validate(
      clubs: candidateClubs,
      players: candidatePlayers,
    );
    if (!candidateIntegrity.isValid) return false;

    final rawFixturesPreflight = snapshot['fixtures'];
    if (rawFixturesPreflight is! List || rawFixturesPreflight.isEmpty) {
      return false;
    }
    final candidateClubIds = candidateClubs.map((club) => club.id).toSet();
    final candidateFixtureKeys = <String>{};
    for (final raw in rawFixturesPreflight) {
      if (raw is! Map) return false;
      final m = Map<String, dynamic>.from(raw);
      final round = m['round'];
      final home = m['homeClubId'];
      final away = m['awayClubId'];
      final year = m['year'];
      final month = m['month'];
      final day = m['day'];
      if (round is! num ||
          home is! String ||
          away is! String ||
          year is! num ||
          month is! num ||
          day is! num ||
          !candidateClubIds.contains(home) ||
          !candidateClubIds.contains(away) ||
          home == away ||
          month.toInt() < 1 ||
          month.toInt() > 12 ||
          day.toInt() < 1 ||
          day.toInt() > 31) {
        return false;
      }
      final key =
          '${round.toInt()}|$home|$away|${year.toInt()}-${month.toInt()}-${day.toInt()}';
      if (!candidateFixtureKeys.add(key)) return false;
    }

    // A pending career transaction must always point at one of the candidate
    // fixtures. Validate this before mutating the live engine.
    final rawCareerMatchPreflight = snapshot['careerMatchSnapshot'];
    if (rawCareerMatchPreflight is Map &&
        rawCareerMatchPreflight['today'] == true) {
      final pendingKey = rawCareerMatchPreflight['fixtureKey'];
      if (pendingKey is! String || !candidateFixtureKeys.contains(pendingKey)) {
        return false;
      }
    }

    // Preflight the scalar game state and career player as well. Parsing them
    // after mutating the live engine would reintroduce the exact partial-LOAD
    // failure mode this transaction is meant to prevent.
    final rawState = snapshot['gameState'];
    if (rawState is! Map) return false;
    late final GameState candidateState;
    try {
      candidateState = GameState.fromJson(Map<String, dynamic>.from(rawState));
    } catch (_) {
      return false;
    }
    if (candidateState.year < 2000 ||
        candidateState.month < 1 || candidateState.month > 12 ||
        candidateState.day < 1 || candidateState.day > 31 ||
        candidateState.season < 2000) {
      return false;
    }

    PlayerCareer? candidateCareerPlayer;
    final rawCareerPreflight = snapshot['careerPlayer'];
    if (rawCareerPreflight != null) {
      if (rawCareerPreflight is! Map) return false;
      try {
        candidateCareerPlayer =
            PlayerCareer.fromJson(Map<String, dynamic>.from(rawCareerPreflight));
      } catch (_) {
        return false;
      }
      if (candidateCareerPlayer!.id.isEmpty) return false;
    }

    final rawStateTransferSummer = rawState['transferWindowSummer'];
    final rawStateTransferWinter = rawState['transferWindowWinter'];
    if (rawStateTransferSummer != null && rawStateTransferSummer is! bool) return false;
    if (rawStateTransferWinter != null && rawStateTransferWinter is! bool) return false;

    // The career player is a separate snapshot from the world roster. Validate
    // its references now, before it can be attached to the live bridge.
    if (candidateCareerPlayer != null) {
      final careerClubId = candidateCareerPlayer!.clubId;
      if (careerClubId != null && !candidateClubIds.contains(careerClubId)) {
        return false;
      }
      final contract = candidateCareerPlayer!.contract;
      if (contract != null) {
        if (!candidateClubIds.contains(contract.clubId)) return false;
        if (careerClubId != null && contract.clubId != careerClubId) return false;
        if (contract.yearsRemaining <= 0) return false;
      }
    }

    // From this point onward all parsing/validation needed for the restore
    // transaction has succeeded. Only now is it safe to mutate the live state.
    state.year = candidateState.year;
    state.month = candidateState.month;
    state.day = candidateState.day;
    state.season = candidateState.season;
    state.transferWindowSummer = candidateState.transferWindowSummer;
    state.transferWindowWinter = candidateState.transferWindowWinter;

    final rawPlayers = snapshot['players'];
    if (rawPlayers is List) {
      // V11 creates and retires real world players. The save therefore has to
      // restore the complete collection, not only mutate players that existed
      // in the original static WorldData list.
      final restoredPlayers = <Player>[];
      for (final p in rawPlayers) {
        if (p is Map) {
          restoredPlayers.add(Player.fromJson(Map<String, dynamic>.from(p)));
        }
      }
      if (restoredPlayers.isNotEmpty) {
        players
          ..clear()
          ..addAll(restoredPlayers);
      }
    }

    final rawClubs = snapshot['clubs'];
    if (rawClubs is List) {
      // Clubs can change league, budget, overall and roster membership over
      // many seasons, so restore the complete collection as well.
      final restoredClubs = <Club>[];
      for (final c in rawClubs) {
        if (c is Map) {
          restoredClubs.add(Club.fromJson(Map<String, dynamic>.from(c)));
        }
      }
      if (restoredClubs.isNotEmpty) {
        clubs
          ..clear()
          ..addAll(restoredClubs);
      }
    }

    final rawFixtures = snapshot['fixtures'];
    if (rawFixtures is List) {
      // Restore the exact persisted schedule instead of trying to merge it
      // into the constructor's default season. This is essential when a save
      // is loaded in season 2027+ or after the fixture format changes.
      final restoredFixtures = <Fixture>[];
      for (final raw in rawFixtures) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final round = m['round'];
        final home = m['homeClubId'];
        final away = m['awayClubId'];
        final year = m['year'];
        final month = m['month'];
        final day = m['day'];
        if (round is! num || home is! String || away is! String ||
            year is! num || month is! num || day is! num) {
          continue;
        }
        final rawResult = m['resultSnapshot'];
        restoredFixtures.add(Fixture(
          round: round.toInt(),
          homeClubId: home,
          awayClubId: away,
          year: year.toInt(),
          month: month.toInt(),
          day: day.toInt(),
          played: m['played'] == true,
          homeGoals: m['homeGoals'] is num ? (m['homeGoals'] as num).toInt() : null,
          awayGoals: m['awayGoals'] is num ? (m['awayGoals'] as num).toInt() : null,
          resultSnapshot: rawResult is Map ? Map<String, dynamic>.from(rawResult) : null,
        ));
      }
      if (restoredFixtures.isNotEmpty) {
        fixtures
          ..clear()
          ..addAll(restoredFixtures);
      }
    }

    final rawWorldEngine = snapshot['worldEngine'];
    if (rawWorldEngine is Map) {
      worldEngine.restoreFromJson(Map<String, dynamic>.from(rawWorldEngine));
    }

    // Migracja numerów koszulek dla starszych zapisów.
    _syncClubRosters();

    // Reject a structurally corrupt world before rebuilding derived state.
    // A partial LOAD must never leave the in-memory engine half-restored.
    final integrity = WorldIntegrityValidator.validate(
      clubs: clubs,
      players: players,
    );
    if (!integrity.isValid) {
      return false;
    }

    // Fixtures are authoritative for the league table. Match the league
    // engine to the saved career before rebuilding, otherwise a 1. Liga save
    // would be rebuilt against the Ekstraklasa table.
    final savedClubId = candidateCareerPlayer?.clubId;
    final savedLeagueId = savedClubId == null
        ? 'pol_ek'
        : (clubs.firstWhere((c) => c.id == savedClubId).leagueId);
    leagueEngine = LeagueEngine(clubs: clubs.where((c) => c.leagueId == savedLeagueId).toList());
    rebuildLeagueFromFixtures();

    _restoreCareerMatchSnapshot(snapshot['careerMatchSnapshot']);

    if (_careerMatchToday) {
      final key = _careerMatchFixtureKey;
      Fixture? matchingFixture;
      if (key != null) {
        for (final candidate in fixtures) {
          final candidateKey =
              '${candidate.round}|${candidate.homeClubId}|${candidate.awayClubId}|${candidate.year}-${candidate.month}-${candidate.day}';
          if (candidateKey == key) {
            matchingFixture = candidate;
            break;
          }
        }
      }
      if (matchingFixture == null) {
        // Never resurrect a transaction that no longer has a matching
        // fixture. This protects against stale/corrupt saves.
        _resetCareerMatchSnapshot();
        return false;
      }
      // After interactive reconciliation the fixture is intentionally marked
      // played before the post-match world tick. A save taken in that narrow
      // window therefore must point to a PLAYED fixture whose score is exactly
      // the score stored in the transaction snapshot.
      if (matchingFixture.played &&
          (matchingFixture.homeGoals != _careerMatchHomeGoals ||
           matchingFixture.awayGoals != _careerMatchAwayGoals)) {
        _resetCareerMatchSnapshot();
        return false;
      }
    }

    // A save without a career player is a valid non-career/world snapshot;
    // do not accidentally retain the career from the engine that was loaded
    // into. candidateCareerPlayer was fully parsed during preflight above.
    careerPlayer = candidateCareerPlayer;
    if (careerPlayer != null) {
      careerWorldBridge.attach(career: careerPlayer!, worldPlayers: players, clubs: clubs);
      careerWorldBridge.pushCareerState(careerPlayer!);
      _syncClubRosters();
      final matchingProjection = players.where((p) => p.id == careerPlayer!.id).toList();
      final projection = matchingProjection.isEmpty ? null : matchingProjection.first;
      if (projection != null) {
        careerPlayer!.shirtNumber = projection.shirtNumber;
        if (careerPlayer!.contract != null) careerPlayer!.contract!.squadNumber = projection.shirtNumber;
      }
    }
    return true;
  }

  // ==========================================================
  // NASTĘPNY DZIEŃ / METODA COMPATIBILITY FOR UI
  // ==========================================================

  void nextDay() {
    advanceDay();
  }

  /// DEV: advances only the autonomous football world. The player's career
  /// match is deliberately NOT played, so this can be used to stress-test
  /// transfers, managers, values and world events without cheating the
  /// player's calendar.
  int simulateWorldOnlyDays(int days) {
    final count = days.clamp(1, 365);
    for (var i = 0; i < count; i++) {
      state.nextDay();
      worldEngine.processDay(
        year: state.year,
        month: state.month,
        day: state.day,
        summerTransferWindow: summerTransferWindow,
        winterTransferWindow: winterTransferWindow,
      );
    }
    return count;
  }

  /// V25: every simulation day enters through one central coordinator.
  ///
  /// The coordinator owns causal order; specialist engines still own the
  /// actual football/world rules.
  DailySimulationReport advanceDay() {
    if (careerHasMatchToday) {
      throw StateError('Dzisiejszy mecz kariery musi zostać rozegrany przed przejściem do następnego dnia.');
    }

    // The previous day is committed before the calendar advances. This makes
    // training/match actions exclusive to their calendar day.
    // Do not reset the action flag before the transaction. The date itself
    // is the reset boundary, so a UI left open across a day change immediately
    // observes a fresh action slot.
    final report = dailySimulationCore.runDay(
      recoverPlayer: recoverPlayer,
      updatePlayerForm: updatePlayerForm,
      updateCareerPlayerMatchStatus: updateCareerPlayerMatchStatus,
      resetCareerMatchSnapshot: _resetCareerMatchSnapshot,
      hasCareerMatchToday: () => careerHasMatchToday,
      playCareerMatches: () {
        playNonCareerMatchesForToday();
        return fixtures.where((f) =>
            f.played &&
            f.year == state.year &&
            f.month == state.month &&
            f.day == state.day).length;
      },
      pushCareerStateBeforeWorld: () {
        if (careerPlayer == null) return;
        careerWorldBridge.attach(
          career: careerPlayer!,
          worldPlayers: players,
          clubs: clubs,
        );
        careerWorldBridge.pushCareerState(careerPlayer!);
      },
      processWorldDay: ({
        required int year,
        required int month,
        required int day,
        required bool summerTransferWindow,
        required bool winterTransferWindow,
      }) {
        worldEngine.processDay(
          year: year,
          month: month,
          day: day,
          summerTransferWindow: summerTransferWindow,
          winterTransferWindow: winterTransferWindow,
        );
        _syncClubRosters();
      },
      applyCareerMatchConsequences: () {
        if (careerPlayer != null && _careerMatchToday) {
          worldEngine.processCareerMatchConsequences(
            career: careerPlayer!,
            year: state.year,
            month: state.month,
            day: state.day,
            homeGoals: _careerMatchHomeGoals,
            awayGoals: _careerMatchAwayGoals,
            playerClubIsHome: _careerMatchClubIsHome,
            appeared: _careerMatchAppeared,
            started: _careerMatchStarted,
            minutes: _careerMatchMinutes,
            rating: _careerMatchRating,
            goals: _careerMatchGoals,
            assists: _careerMatchAssists,
          );
        }
      },
      pullCareerStateAfterWorld: () {
        if (careerPlayer != null) {
          careerWorldBridge.pullWorldState(
            careerPlayer!,
            worldPlayers: players,
            clubs: clubs,
          );
        }
      },
      advanceSeasonIfComplete: () {
        if (!leagueEngine.isSeasonComplete()) return false;

        // A double-round league can finish before the football season's
        // calendar boundary (the return leg currently ends in spring).
        // Do not generate the next season while the calendar is still in
        // the old campaign: doing so would create July fixtures in the past
        // and leave the new season unreachable by exact-date simulation.
        // The transition is committed on/after 30 June, immediately before
        // GameState rolls into the next season on 1 July.
        final calendarEnd = DateTime(state.year, 6, 30);
        final currentDate = DateTime(state.year, state.month, state.day);
        if (currentDate.isBefore(calendarEnd)) return false;

        _advanceSeason();
        return true;
      },
    );
    if (!validateSimulationIntegrity()) {
      throw StateError('Integralność świata została naruszona po przejściu dnia.');
    }
    if (GameSettings.autoSave) unawaited(saveWorld());
    return report;
  }

  int _calculateCareerPlayerGoals({required PlayerCareer player, required MatchResult result, required bool playerClubIsHome, required int minutes}) {
    final teamGoals = playerClubIsHome ? result.homeGoals : result.awayGoals;
    if (teamGoals <= 0 || minutes <= 0) return 0;
    final share = switch (player.position) {
      PlayerPosition.striker => 0.38,
      PlayerPosition.winger => 0.24,
      PlayerPosition.midfielder => 0.12,
      PlayerPosition.defender => 0.04,
      PlayerPosition.goalkeeper => 0.005,
    };
    var goals = 0;
    for (var i = 0; i < teamGoals; i++) { if (_random.nextDouble() < share * (minutes / 90)) goals++; }
    return goals.clamp(0, teamGoals);
  }

  int _calculateCareerPlayerAssists({required PlayerCareer player, required MatchResult result, required bool playerClubIsHome, required int minutes}) {
    final teamGoals = playerClubIsHome ? result.homeGoals : result.awayGoals;
    if (teamGoals <= 0 || minutes <= 0) return 0;
    final share = switch (player.position) {
      PlayerPosition.striker => 0.12,
      PlayerPosition.winger => 0.28,
      PlayerPosition.midfielder => 0.34,
      PlayerPosition.defender => 0.08,
      PlayerPosition.goalkeeper => 0.01,
    };
    var assists = 0;
    for (var i = 0; i < teamGoals; i++) { if (_random.nextDouble() < share * (minutes / 90)) assists++; }
    return assists.clamp(0, teamGoals);
  }

  // ==========================================================
  // PRZEJŚCIE DO NOWEGO SEZONU
  // ==========================================================

  void _advanceSeason() {
    // This method can run on 30 June or immediately after the calendar rolls
    // to 1 July. The latter case already has the correct new season year in
    // GameState, so do not add another year there.
    final nextSeasonStartYear = state.month == 7 && state.day == 1 ? state.year : state.year + 1;

    // Świat ma własny cykl rozwoju, starzenia, kontraktów, finansów
    // i emerytur. GameEngine tylko go uruchamia.
    worldEngine.processEndOfSeason(nextSeasonStartYear: nextSeasonStartYear);

    // Starzenie gracza kariery
    if (careerPlayer != null) {
      careerPlayer!.age += 1;
    }

    // 3. Reset tabeli i wygenerowanie nowego terminarza
    final careerClub = careerPlayer?.clubId == null
        ? null
        : clubs.where((c) => c.id == careerPlayer!.clubId).isEmpty ? null : clubs.where((c) => c.id == careerPlayer!.clubId).first;
    final careerLeagueId = careerClub?.leagueId ?? 'pol_ek';
    final leagueClubs = clubs.where((club) => club.leagueId == careerLeagueId).toList();
    if (leagueClubs.length < 2) {
      throw StateError('Nie można wygenerować nowego sezonu: liga kariery ma mniej niż 2 kluby.');
    }
    leagueEngine = LeagueEngine(clubs: leagueClubs);
    fixtures
      ..clear()
      ..addAll(FixtureGenerator.generateSeasonFixtures(leagueClubs, seasonStartYear: nextSeasonStartYear));
    if (careerPlayer != null) {
      careerPlayer!.ensureDevelopmentSeason(nextSeasonStartYear);
      careerPlayer!.seasonStartOverall = careerPlayer!.overall;
    }
  }

  // ==========================================================
  // INFORMACJE O UDZIALE ZAWODNIKA W MECZU
  // ==========================================================

  bool get careerPlayerCanPlay {
    if (careerPlayer == null) {
      return false;
    }

    final player = careerPlayer!;

    // Bez klubu nie można grać.
    if (player.clubId == null) {
      return false;
    }

    // Aktualizacja decyzji trenera.
    player.updateMatchStatus();

    return player.canPlayMatch;
  }

  // ==========================================================
  // CZY ZAWODNIK JEST W KADRZE MECZOWEJ
  // ==========================================================

  bool get careerPlayerInMatchSquad {
    if (careerPlayer == null) {
      return false;
    }

    return careerPlayer!.inMatchSquad;
  }

  // ==========================================================
  // CZY ZAWODNIK JEST W PODSTAWOWYM SKŁADZIE
  // ==========================================================

  bool get careerPlayerIsStarter {
    if (careerPlayer == null) {
      return false;
    }

    return careerPlayer!.isRegularStarter;
  }

  // ==========================================================
  // STATUS MECZOWY ZAWODNIKA
  // ==========================================================

  String get careerPlayerMatchStatus {
    if (careerPlayer == null) {
      return 'Brak zawodnika';
    }

    return careerPlayer!.squadStatus;
  }

  // ==========================================================
  // WYSTĘP ZAWODNIKA W MECZU
  // ==========================================================

  void processCareerPlayerMatch({
    required Fixture fixture,
    required MatchResult result,
  }) {
    if (careerPlayer == null) return;

    final player = careerPlayer!;
    if (player.clubId == null) return;

    final playerClubIsHome = fixture.homeClubId == player.clubId;
    final playerClubIsAway = fixture.awayClubId == player.clubId;
    if (!playerClubIsHome && !playerClubIsAway) return;

    final fixtureKey = '${fixture.round}|${fixture.homeClubId}|${fixture.awayClubId}|${fixture.year}-${fixture.month}-${fixture.day}';
    // Hard idempotency guard. Save/Load also persists this set.
    if (!_processedCareerFixtureKeys.add(fixtureKey)) {
      return;
    }

    _careerMatchToday = true;
    _dailyCareerActionConsumed = true;
    _dailyCareerAction = 'match';
    _dailyCareerActionDay = currentAbsoluteDay;
    _careerMatchClubId = player.clubId;
    _careerMatchClubIsHome = playerClubIsHome;
    _careerMatchFixtureKey = fixtureKey;
    _careerMatchHomeGoals = result.homeGoals;
    _careerMatchAwayGoals = result.awayGoals;

    player.updateMatchStatus();
    if (!player.canPlayMatch) return;

    // Interactive 2D matches provide the actual performance. This prevents
    // the profile from receiving a second, unrelated random result.
    final supplied = result.performanceForPlayer(player.id);
    bool started;
    int minutes;
    int goals;
    int assists;
    double rating;
    int shots;
    int shotsOnTarget;
    int keyPasses;
    int dribbles;
    int yellow;
    int red;

    if (supplied != null && supplied.minutes > 0) {
      started = supplied.started;
      minutes = supplied.minutes;
      goals = supplied.goals;
      assists = supplied.assists;
      rating = supplied.rating;
      shots = supplied.shots;
      shotsOnTarget = supplied.shotsOnTarget;
      keyPasses = supplied.keyPasses;
      dribbles = supplied.successfulDribbles;
      yellow = supplied.yellowCards;
      red = supplied.redCards;
      player.inMatchSquad = true;
      player.isStarter = started;
      player.isRegularStarter = started;
    } else {
      started = player.isStarter;
      minutes = started
          ? (_random.nextInt(100) < 75 ? 90 : 60 + _random.nextInt(30))
          : (player.inMatchSquad && _random.nextInt(100) < 60
              ? max(10, 90 - (55 + _random.nextInt(26)))
              : 0);
      if (minutes <= 0) return;

      goals = _calculateCareerPlayerGoals(
        player: player, result: result, playerClubIsHome: playerClubIsHome, minutes: minutes);
      assists = _calculateCareerPlayerAssists(
        player: player, result: result, playerClubIsHome: playerClubIsHome, minutes: minutes);
      rating = careerMatchRatingEngine.calculate(
        player: player, result: result, playerClubIsHome: playerClubIsHome,
        started: started, minutes: minutes, goals: goals, assists: assists);

      final teamShots = playerClubIsHome ? result.homeShots : result.awayShots;
      final teamOnTarget = playerClubIsHome ? result.homeShotsOnTarget : result.awayShotsOnTarget;
      final shotShare = player.position == PlayerPosition.striker
          ? 0.28 : player.position == PlayerPosition.winger
              ? 0.20 : player.position == PlayerPosition.midfielder
                  ? 0.13 : player.position == PlayerPosition.defender ? 0.06 : 0.02;
      final expectedShots = max(0, (teamShots * shotShare * minutes / 90).round());
      shots = max(goals, expectedShots);
      shotsOnTarget = min(shots, max(goals, (shots * (teamShots == 0 ? 0.35 : teamOnTarget / teamShots)).round()));
      final keyPassesShare = player.position == PlayerPosition.midfielder || player.position == PlayerPosition.winger ? 0.10 : 0.04;
      keyPasses = (result.totalGoals * keyPassesShare * minutes / 90).round() + (assists > 0 ? assists : 0);
      final dribbleShare = player.position == PlayerPosition.winger || player.position == PlayerPosition.striker ? 0.08 : 0.03;
      dribbles = (minutes * dribbleShare).round();
      yellow = _random.nextDouble() < (minutes / 90) * 0.10 ? 1 : 0;
      red = yellow == 1 && _random.nextDouble() < 0.015 ? 1 : 0;
    }

    _careerMatchAppeared = true;
    _careerMatchStarted = started;
    _careerMatchMinutes = minutes;
    _careerMatchRating = rating;
    _careerMatchGoals = goals;
    _careerMatchAssists = assists;

    player.addCareerAppearance(minutes: minutes, started: started, rating: rating);
    for (var i = 0; i < goals; i++) player.addCareerGoal();
    for (var i = 0; i < assists; i++) player.addCareerAssist();
    player.matchStats.shots += shots.round();
    player.matchStats.shotsOnTarget += shotsOnTarget.round();
    player.matchStats.keyPasses += max(0, keyPasses).round();
    player.matchStats.successfulDribbles += max(0, dribbles).round();
    player.matchStats.yellowCards += yellow;
    player.matchStats.redCards += red;

    final matchFatigue = started ? 25 + ((minutes - 60) ~/ 6) : 8 + (minutes ~/ 5);
    player.fatigue = (player.fatigue + matchFatigue).clamp(0, 100);
    player.fitness = (player.fitness - matchFatigue).clamp(0, 100);

    if (rating >= 7.5) {
      player.form = (player.form + 3).clamp(0, 100);
    } else if (rating >= 7.0) {
      player.form = (player.form + 2).clamp(0, 100);
    } else if (rating < 5.5) {
      player.form = (player.form - 2).clamp(0, 100);
    } else if (rating < 6.0) {
      player.form = (player.form - 1).clamp(0, 100);
    }
  }

  void _applyPerformanceDevelopment() {
    final p = careerPlayer;
    if (p == null || !_careerMatchAppeared) return;
    p.applyPerformanceGrowth(
      season: state.season,
      minutes: _careerMatchMinutes,
      rating: _careerMatchRating,
      goals: _careerMatchGoals,
      assists: _careerMatchAssists,
    );
  }

  void _resetCareerMatchSnapshot() {
    _careerMatchToday = false;
    _careerMatchAppeared = false;
    _careerMatchStarted = false;
    _careerMatchMinutes = 0;
    _careerMatchGoals = 0;
    _careerMatchAssists = 0;
    _careerMatchRating = 6.0;
    _careerMatchHomeGoals = 0;
    _careerMatchAwayGoals = 0;
    _careerMatchClubId = null;
    _careerMatchClubIsHome = false;
    _careerMatchFixtureKey = null;
  }

  /// Resolves only fixtures that do not belong to the career player.
  /// The player's fixture is an interactive transaction and MUST remain
  /// unplayed until MatchScreen commits its final result.
  int playNonCareerMatchesForToday() {
    final careerClubId = careerPlayer?.clubId;
    var completed = 0;
    final todays = fixtures.where((f) =>
        !f.played &&
        f.year == state.year &&
        f.month == state.month &&
        f.day == state.day &&
        (careerClubId == null ||
            (f.homeClubId != careerClubId && f.awayClubId != careerClubId))).toList();
    for (final fixture in todays) {
      playFixture(fixture);
      completed++;
    }
    return completed;
  }

  /// Legacy bulk entry point used by the match screen after the interactive
  /// career fixture has been committed. It is intentionally safe: if the
  /// player's fixture is still pending, it is left untouched.
  void playMatchesForToday() {
    playNonCareerMatchesForToday();
  }

  /// Finalizes the current interactive career-match day. This is the second
  /// half of the daily transaction: the player's final result is already in
  /// the fixture, then career consequences, AI fixtures and the world tick
  /// are committed exactly once.
  DailySimulationReport finalizeCareerMatchDay() {
    if (!careerHasMatchToday && !_careerMatchToday) {
      throw StateError('Brak oczekującego meczu kariery do finalizacji.');
    }

    applyCareerMatchConsequencesForCurrentDay();
    _applyPerformanceDevelopment();
    playNonCareerMatchesForToday();

    if (careerPlayer != null) {
      careerWorldBridge.attach(
        career: careerPlayer!,
        worldPlayers: players,
        clubs: clubs,
      );
      careerWorldBridge.pushCareerState(careerPlayer!);
    }

    worldEngine.processDay(
      year: state.year,
      month: state.month,
      day: state.day,
      summerTransferWindow: state.transferWindowSummer,
      winterTransferWindow: state.transferWindowWinter,
    );

    if (careerPlayer != null) {
      careerWorldBridge.pullWorldState(
        careerPlayer!,
        worldPlayers: players,
        clubs: clubs,
      );
    }

    var seasonAdvanced = false;
    if (leagueEngine.isSeasonComplete()) {
      final calendarEnd = DateTime(state.year, 6, 30);
      final currentDate = DateTime(state.year, state.month, state.day);
      if (!currentDate.isBefore(calendarEnd)) {
        _advanceSeason();
        seasonAdvanced = true;
      }
    }

    final phases = <DailySimulationPhase>[
      DailySimulationPhase.dateAdvanced,
      DailySimulationPhase.playerRecovery,
      DailySimulationPhase.playerForm,
      DailySimulationPhase.squadDecision,
      DailySimulationPhase.careerMatches,
      DailySimulationPhase.worldAi,
      DailySimulationPhase.careerWorldBridge,
      DailySimulationPhase.seasonMaintenance,
    ];
    final absoluteDay = DateTime(state.year, state.month, state.day)
        .difference(DateTime(2000, 1, 1)).inDays;
    final report = DailySimulationReport(
      year: state.year,
      month: state.month,
      day: state.day,
      absoluteDay: absoluteDay,
      phases: List.unmodifiable(phases),
      careerMatchesCompleted: 1,
      seasonAdvanced: seasonAdvanced,
    );

    // The interactive match transaction is fully committed at this point.
    // Clear its transient snapshot before returning so a SAVE immediately
    // after the match cannot re-apply match consequences after LOAD. This
    // also makes finalizeCareerMatchDay() naturally non-repeatable: a second
    // tap/call fails instead of running the world tick twice.
    _resetCareerMatchSnapshot();
    if (!validateSimulationIntegrity()) {
      throw StateError('Integralność świata została naruszona po zakończeniu meczu.');
    }
    dailySimulationCore.lastReport = report;
    if (GameSettings.autoSave) unawaited(saveWorld());
    return report;
  }

  void applyCareerMatchConsequencesForCurrentDay() {
    if (careerPlayer == null || !_careerMatchToday) return;
    worldEngine.processCareerMatchConsequences(
      career: careerPlayer!,
      year: state.year,
      month: state.month,
      day: state.day,
      homeGoals: _careerMatchHomeGoals,
      awayGoals: _careerMatchAwayGoals,
      playerClubIsHome: _careerMatchClubIsHome,
      appeared: _careerMatchAppeared,
      started: _careerMatchStarted,
      minutes: _careerMatchMinutes,
      rating: _careerMatchRating,
      goals: _careerMatchGoals,
      assists: _careerMatchAssists,
    );
  }

  /// Generates the official pre-match target without committing the fixture.
  /// Interactive 2D matches use this preview so the final score is committed
  /// only when the match actually finishes. This keeps table/statistics/save
  /// state transactional and prevents a half-played match from counting.
  MatchResult previewFixture(Fixture fixture) {
    if (fixture.played) {
      final stored = fixture.storedResult;
      if (stored != null) return stored;
      if (fixture.homeGoals == null || fixture.awayGoals == null) {
        throw StateError('Played fixture ${fixture.homeClubId}-${fixture.awayClubId} has no score.');
      }
      return MatchResult(
        homeClubId: fixture.homeClubId,
        awayClubId: fixture.awayClubId,
        homeGoals: fixture.homeGoals!,
        awayGoals: fixture.awayGoals!,
      );
    }
    final home = clubs.firstWhere((club) => club.id == fixture.homeClubId);
    final away = clubs.firstWhere((club) => club.id == fixture.awayClubId);
    return matchEngine.simulate(home: home, away: away);
  }

  MatchResult playFixture(Fixture fixture) {
    // A fixture is a transaction: once it is completed it must never be
    // simulated/recorded a second time. This is the central guard that keeps
    // Match Screen, Table, World Tick and Save/Load on the same timeline.
    if (fixture.played) {
      if (fixture.homeGoals == null || fixture.awayGoals == null) {
        throw StateError('Played fixture ${fixture.homeClubId}-${fixture.awayClubId} has no score.');
      }
      final stored = fixture.storedResult;
      if (stored != null) return stored;
      return MatchResult(
        homeClubId: fixture.homeClubId,
        awayClubId: fixture.awayClubId,
        homeGoals: fixture.homeGoals!,
        awayGoals: fixture.awayGoals!,
      );
    }

    final home = clubs.firstWhere((club) => club.id == fixture.homeClubId);
    final away = clubs.firstWhere((club) => club.id == fixture.awayClubId);
    final result = matchEngine.simulate(home: home, away: away);

    fixture.played = true;
    fixture.homeGoals = result.homeGoals;
    fixture.awayGoals = result.awayGoals;
    fixture.storeResult(result);

    leagueEngine.recordMatch(
      homeClubId: result.homeClubId,
      awayClubId: result.awayClubId,
      homeGoals: result.homeGoals,
      awayGoals: result.awayGoals,
    );

    processCareerPlayerMatch(fixture: fixture, result: result);
    if (!validateLeagueIntegrity()) {
      throw StateError('League integrity failed after fixture completion.');
    }
    return result;
  }

  /// Completes every unplayed fixture scheduled for one exact calendar day.
  /// This is intentionally the only bulk-match entry point used by day flow.
  int completeFixturesForDate(int year, int month, int day) {
    var completed = 0;
    final todays = fixtures.where((f) =>
        !f.played && f.year == year && f.month == month && f.day == day).toList();
    for (final fixture in todays) {
      playFixture(fixture);
      completed++;
    }
    return completed;
  }


  /// Phase 6 / 80: commits the complete gameplay-generated MatchResult.
  /// The gameplay layer is now the official result authority for the
  /// interactive career fixture. This method owns the single league/career
  /// transaction and never re-simulates the fixture.
  void commitGameplayMatchResult({
    required Fixture fixture,
    required MatchResult result,
  }) {
    if (result.homeClubId != fixture.homeClubId ||
        result.awayClubId != fixture.awayClubId) {
      throw StateError('Wynik gameplay nie pasuje do aktualnego meczu.');
    }
    if (result.homeGoals < 0 || result.awayGoals < 0 ||
        result.homeGoals > 99 || result.awayGoals > 99) {
      throw ArgumentError('Nieprawidłowy wynik meczu.');
    }
    final playerClubId = careerPlayer?.clubId;
    final isCareerFixture = playerClubId != null &&
        (fixture.homeClubId == playerClubId || fixture.awayClubId == playerClubId) &&
        fixture.year == state.year &&
        fixture.month == state.month &&
        fixture.day == state.day;
    if (!isCareerFixture) {
      throw StateError('Nie można zatwierdzić meczu spoza aktualnego dnia kariery.');
    }
    if (fixture.played) {
      if (fixture.homeGoals == result.homeGoals &&
          fixture.awayGoals == result.awayGoals) return;
      throw StateError('Fixture został już rozegrany z innym wynikiem.');
    }

    fixture.played = true;
    fixture.homeGoals = result.homeGoals;
    fixture.awayGoals = result.awayGoals;
    fixture.storeResult(result);

    leagueEngine.recordMatch(
      homeClubId: result.homeClubId,
      awayClubId: result.awayClubId,
      homeGoals: result.homeGoals,
      awayGoals: result.awayGoals,
    );
    processCareerPlayerMatch(fixture: fixture, result: result);

    if (!validateLeagueIntegrity()) {
      throw StateError('League integrity failed after gameplay fixture completion.');
    }
  }

  /// Legacy compatibility path for older interactive match flows.
  /// New career 2D matches must use commitGameplayMatchResult(), where the
  /// gameplay-generated MatchResult is the sole authoritative result.
  void reconcileInteractiveFixtureResult({
    required Fixture fixture,
    required int finalHomeGoals,
    required int finalAwayGoals,
    PlayerMatchPerformance? careerPerformance,
    Match2DStats? interactiveStats,
  }) {
    // Release-candidate boundary: the interactive layer may only commit a
    // sane score for the player's fixture on the current calendar day. This
    // prevents stale MatchScreen instances (or double taps after navigation)
    // from rewriting an unrelated fixture.
    if (finalHomeGoals < 0 || finalAwayGoals < 0 ||
        finalHomeGoals > 99 || finalAwayGoals > 99) {
      throw ArgumentError('Nieprawidłowy wynik meczu.');
    }
    final playerClubId = careerPlayer?.clubId;
    final isCareerFixture = playerClubId != null &&
        (fixture.homeClubId == playerClubId || fixture.awayClubId == playerClubId) &&
        fixture.year == state.year &&
        fixture.month == state.month &&
        fixture.day == state.day;
    if (!isCareerFixture) {
      throw StateError('Nie można zatwierdzić meczu spoza aktualnego dnia kariery.');
    }

    if (fixture.played &&
        fixture.homeGoals == finalHomeGoals &&
        fixture.awayGoals == finalAwayGoals) {
      return;
    }

    final wasPlayed = fixture.played;
    final oldHome = fixture.homeGoals;
    final oldAway = fixture.awayGoals;

    fixture.played = true;
    fixture.homeGoals = finalHomeGoals;
    fixture.awayGoals = finalAwayGoals;
    final stored = fixture.storedResult;
    fixture.storeResult(MatchResult(
      homeClubId: stored?.homeClubId ?? fixture.homeClubId,
      awayClubId: stored?.awayClubId ?? fixture.awayClubId,
      homeGoals: finalHomeGoals,
      awayGoals: finalAwayGoals,
      events: stored?.events ?? const [],
      homeShots: interactiveStats?.homeShots ?? stored?.homeShots ?? 0,
      awayShots: interactiveStats?.awayShots ?? stored?.awayShots ?? 0,
      homeShotsOnTarget: interactiveStats?.homeShotsOnTarget ?? stored?.homeShotsOnTarget ?? 0,
      awayShotsOnTarget: interactiveStats?.awayShotsOnTarget ?? stored?.awayShotsOnTarget ?? 0,
      homeCorners: interactiveStats?.homeCorners ?? stored?.homeCorners ?? 0,
      awayCorners: interactiveStats?.awayCorners ?? stored?.awayCorners ?? 0,
      homeFouls: interactiveStats?.homeFouls ?? stored?.homeFouls ?? 0,
      awayFouls: interactiveStats?.awayFouls ?? stored?.awayFouls ?? 0,
      homeYellowCards: interactiveStats?.homeYellowCards ?? stored?.homeYellowCards ?? 0,
      awayYellowCards: interactiveStats?.awayYellowCards ?? stored?.awayYellowCards ?? 0,
      homeRedCards: interactiveStats?.homeRedCards ?? stored?.homeRedCards ?? 0,
      awayRedCards: interactiveStats?.awayRedCards ?? stored?.awayRedCards ?? 0,
      possessionHome: interactiveStats == null ? (stored?.possessionHome ?? 50) : interactiveStats.homePossessionPercent.round(),
      playerPerformances: careerPerformance == null
          ? (stored?.playerPerformances ?? const [])
          : [careerPerformance],
    ));

    if (wasPlayed) {
      leagueEngine.replaceMatch(
        homeClubId: fixture.homeClubId,
        awayClubId: fixture.awayClubId,
        oldHomeGoals: oldHome ?? 0,
        oldAwayGoals: oldAway ?? 0,
        newHomeGoals: finalHomeGoals,
        newAwayGoals: finalAwayGoals,
      );
    } else {
      leagueEngine.recordMatch(
        homeClubId: fixture.homeClubId,
        awayClubId: fixture.awayClubId,
        homeGoals: finalHomeGoals,
        awayGoals: finalAwayGoals,
      );
      // Career statistics are committed exactly once, using the final
      // interactive result rather than the pre-match preview.
      processCareerPlayerMatch(
        fixture: fixture,
        result: fixture.storedResult!,
      );
    }

    if (!validateLeagueIntegrity()) {
      throw StateError('League integrity failed after interactive fixture reconciliation.');
    }
  }

  /// Full daily-simulation invariant check. This is deliberately stricter
  /// than the league-only check because an Open Beta save must never carry a
  /// broken player/club graph or a career fixture stranded in the past.
  /// It is read-only apart from rebuilding the local roster index from the
  /// authoritative Player.clubId values.
  bool validateSimulationIntegrity() {
    if (state.year < 2000 || state.month < 1 || state.month > 12) return false;
    final maxDay = switch (state.month) {
      2 => (state.year % 400 == 0 || (state.year % 4 == 0 && state.year % 100 != 0)) ? 29 : 28,
      4 || 6 || 9 || 11 => 30,
      _ => 31,
    };
    if (state.day < 1 || state.day > maxDay || state.season < 2000) return false;

    _syncClubRosters();
    if (!WorldIntegrityValidator.validate(clubs: clubs, players: players).isValid) return false;
    if (!validateLeagueIntegrity()) return false;

    final careerClubId = careerPlayer?.clubId;
    if (careerClubId != null && clubs.where((c) => c.id == careerClubId).isEmpty) return false;

    if (careerClubId != null) {
      final now = DateTime(state.year, state.month, state.day);
      for (final fixture in fixtures) {
        if (fixture.played) continue;
        if (fixture.homeClubId != careerClubId && fixture.awayClubId != careerClubId) continue;
        final fixtureDate = DateTime(fixture.year, fixture.month, fixture.day);
        if (fixtureDate.isBefore(now)) return false;
      }
      if (careerHasMatchToday && nextCareerFixture == null) return false;
    }
    return true;
  }

  /// Cheap runtime invariant check used after every league mutation. It
  /// catches the exact class of bugs where a fixture says one thing while the
  /// table says another. It never mutates state.
  bool validateLeagueIntegrity() {
    final expected = <String, List<int>>{};
    for (final c in leagueEngine.clubs) {
      expected[c.id] = [0, 0, 0, 0, 0, 0];
    }
    for (final f in fixtures) {
      if (!f.played || f.homeGoals == null || f.awayGoals == null) continue;
      final h = expected[f.homeClubId];
      final a = expected[f.awayClubId];
      if (h == null || a == null) continue;
      h[0]++; a[0]++; h[1] += f.homeGoals!; h[2] += f.awayGoals!;
      a[1] += f.awayGoals!; a[2] += f.homeGoals!;
      if (f.homeGoals! > f.awayGoals!) { h[3]++; a[5]++; }
      else if (f.homeGoals! < f.awayGoals!) { a[3]++; h[5]++; }
      else { h[4]++; a[4]++; }
    }
    for (final e in expected.entries) {
      final s = leagueEngine.standings[e.key];
      if (s == null) return false;
      final x = e.value;
      if (s.played != x[0] || s.goalsFor != x[1] || s.goalsAgainst != x[2] ||
          s.wins != x[3] || s.draws != x[4] || s.losses != x[5]) return false;
    }
    return true;
  }

  /// Rebuilds the league table from persisted fixtures. This is the single
  /// source of truth after loading a save and prevents a table/fixture split.
  void rebuildLeagueFromFixtures() {
    leagueEngine.resetSeason();
    for (final fixture in fixtures) {
      if (!fixture.played) continue;
      final hg = fixture.homeGoals;
      final ag = fixture.awayGoals;
      if (hg == null || ag == null) continue;
      leagueEngine.recordMatch(
        homeClubId: fixture.homeClubId,
        awayClubId: fixture.awayClubId,
        homeGoals: hg,
        awayGoals: ag,
      );
    }
  }

  // ==========================================================
  // TRENING
  // ==========================================================

  TrainingResult trainPlayer(
    TrainingType type,
  ) {
    if (careerPlayer == null) {
      throw StateError(
        'Brak aktywnego zawodnika.',
      );
    }

    final player = careerPlayer!;

    // Bug fix (V26): this must use the day-aware getter, not the raw flag.
    // `_dailyCareerActionConsumed` is set to true by training/match and is
    // never reset on its own — only `_dailyCareerActionDay` scopes it to a
    // single calendar day. Checking the raw flag here meant that after the
    // very first successful training (or match), every future training
    // attempt on every future day threw this error immediately, even though
    // the training button correctly showed as enabled (it reads the
    // day-aware `dailyCareerActionConsumed` getter).
    if (dailyCareerActionConsumed) {
      throw StateError(
        'Dzisiejsza akcja kariery została już wykonana. Przejdź do następnego dnia.',
      );
    }

    if (careerHasMatchToday) {
      throw StateError(
        'Dzisiaj jest mecz. Trening możesz wykonać w dniu bez spotkania.',
      );
    }

    if (player.fatigue >= 90) {
      throw StateError(
        'Zawodnik jest zbyt zmęczony na kolejny trening.',
      );
    }

    player.ensureDevelopmentSeason(state.season);
    final result = trainingEngine.train(
      player,
      type,
    );

    player.fatigue = (
      player.fatigue + result.fatigue
    ).clamp(0, 100);

    player.fitness = (
      player.fitness - result.fatigue
    ).clamp(0, 100);

    player.refreshOverall();

    // Dobry trening wpływa na zaufanie trenera.
    player.rewardTrainingTrust();
    _dailyCareerActionConsumed = true;
    _dailyCareerAction = 'training';
    _dailyCareerActionDay = currentAbsoluteDay;

    return result;
  }

  // ==========================================================
  // REGENERACJA
  // ==========================================================

  void recoverPlayer() {
    if (careerPlayer == null) {
      return;
    }

    final player = careerPlayer!;

    final recovery = player.fatigue >= 70
        ? 5
        : player.fatigue >= 40
            ? 8
            : 10;

    player.fatigue = (
      player.fatigue - recovery
    ).clamp(0, 100);

    player.fitness = (
      player.fitness + recovery
    ).clamp(0, 100);
  }

  // ==========================================================
  // FORMA ZAWODNIKA
  // ==========================================================

  void updatePlayerForm() {
    if (careerPlayer == null) {
      return;
    }

    final player = careerPlayer!;

    if (player.fatigue >= 80) {
      player.form = (
        player.form - 2
      ).clamp(0, 100);
    } else if (player.fatigue >= 60) {
      player.form = (
        player.form - 1
      ).clamp(0, 100);
    } else if (player.fatigue <= 25) {
      player.form = (
        player.form + 1
      ).clamp(0, 100);
    }
  }

  // ==========================================================
  // DECYZJA TRENERA O STATUSIE ZAWODNIKA
  // ==========================================================

  void updateCareerPlayerMatchStatus() {
    if (careerPlayer == null) {
      return;
    }

    final player = careerPlayer!;

    // Jeżeli zawodnik nie ma klubu, nie może być wybierany do kadry.
    if (player.clubId == null) {
      player.inMatchSquad = false;
      player.isStarter = false;
      player.squadStatus = 'Bez klubu';
      return;
    }

    player.updateMatchStatus();

    if (!player.canPlayMatch) {
      player.isStarter = false;
    }
  }

  // ==========================================================
  // PRZYPISANIE DO KLUBU
  // ==========================================================

  void assignPlayerToClub(
    String clubId,
  ) {
    if (careerPlayer == null) {
      throw StateError(
        'Najpierw utwórz zawodnika.',
      );
    }

    final club = clubs.firstWhere(
      (club) => club.id == clubId,
    );

    final player = careerPlayer!;

    player.clubId = clubId;

    player.shirtNumber = _availableShirtNumber(club);

    player.managerRelationship = 50;
    player.teamRelationship = 55;

    player.updateMatchStatus();

    final marketValue =
        calculateStartingMarketValue(
      player,
      club,
    );

    final salary =
        calculateStartingSalary(
      player,
      club,
    );

    player.contract = PlayerContract(
      clubId: club.id,
      yearsRemaining: 3,
      weeklySalary: salary,
      marketValue: marketValue,
      squadNumber: player.shirtNumber,
      squadStatus: player.squadStatus,
      managerTrust: player.managerRelationship,
    );

    final selectedLeagueClubs = clubs.where((c) => c.leagueId == club.leagueId).toList();
    leagueEngine = LeagueEngine(clubs: selectedLeagueClubs);
    fixtures
      ..clear()
      ..addAll(FixtureGenerator.generateSeasonFixtures(selectedLeagueClubs, seasonStartYear: state.season));
    careerPlayer!.ensureDevelopmentSeason(state.season);
    careerWorldBridge.attach(career: careerPlayer!, worldPlayers: players, clubs: clubs);
    careerWorldBridge.pushCareerState(careerPlayer!);
    _syncClubRosters();
    final projection = players.where((p) => p.id == careerPlayer!.id).toList();
    if (projection.isNotEmpty) {
      careerPlayer!.shirtNumber = projection.first.shirtNumber;
      careerPlayer!.contract?.squadNumber = projection.first.shirtNumber;
    }
  }

  int _availableShirtNumber(Club club) {
    final used = players.where((p) => p.clubId == club.id && p.shirtNumber > 0).map((p) => p.shirtNumber).toSet();
    for (var n = 1; n <= 99; n++) {
      if (!used.contains(n)) return n;
    }
    return 99;
  }

  void configureCareerContract({required int years, required double weeklySalary, required int shirtNumber}) {
    final player = careerPlayer;
    final contract = player?.contract;
    if (player == null || contract == null) return;
    contract.yearsRemaining = years.clamp(1, 5).toInt();
    contract.weeklySalary = weeklySalary.clamp(50, 100000).toDouble();
    var number = shirtNumber.clamp(1, 99).toInt();
    final occupied = players.where((p) => p.clubId == player.clubId && p.id != player.id && p.shirtNumber == number).isNotEmpty;
    if (occupied) number = _availableShirtNumber(clubs.firstWhere((c) => c.id == player.clubId));
    player.shirtNumber = number;
    contract.squadNumber = number;
    careerWorldBridge.attach(career: player, worldPlayers: players, clubs: clubs);
    careerWorldBridge.pushCareerState(player);
  }

  // ==========================================================
  // WARTOŚĆ POCZĄTKOWA ZAWODNIKA
  // ==========================================================

  double calculateStartingMarketValue(
    PlayerCareer player,
    Club club,
  ) {
    final ageFactor = player.age <= 21
        ? 1.25
        : player.age <= 25
            ? 1.10
            : 0.90;

    final potentialFactor =
        player.potential / 70;

    final clubFactor =
        club.overall / 70;

    return 250000 *
        player.overall *
        ageFactor *
        potentialFactor *
        clubFactor;
  }

  // ==========================================================
  // PENSJA POCZĄTKOWA
  // ==========================================================

  double calculateStartingSalary(
    PlayerCareer player,
    Club club,
  ) {
    const baseSalary = 150.0;

    final overallFactor =
        player.overall / 50;

    final clubFactor =
        club.overall / 70;

    return baseSalary *
        overallFactor *
        clubFactor;
  }

  // ==========================================================
  // TERMINARZ
  // ==========================================================

  List<Fixture> get todayFixtures {
    return fixtures.where(
      (fixture) =>
          fixture.year == state.year &&
          fixture.month == state.month &&
          fixture.day == state.day,
    ).toList();
  }

  List<Fixture> get playedFixtures {
    return fixtures.where(
      (fixture) => fixture.played,
    ).toList();
  }

  List<Fixture> get upcomingFixtures {
    return fixtures.where(
      (fixture) => !fixture.played,
    ).toList();
  }

  /// Najbliższy nierozegrany mecz zawodnika, niezależnie od tego czy
  /// przypada dzisiaj czy za kilka dni. UI używa tego do pokazania
  /// prawdziwego następnego spotkania zamiast sztucznego przycisku meczu.
  Fixture? get nextCareerFixture {
    final clubId = careerPlayer?.clubId;
    if (clubId == null) return null;
    final now = DateTime(state.year, state.month, state.day);
    final matches = fixtures.where((f) {
      if (f.played) return false;
      if (f.homeClubId != clubId && f.awayClubId != clubId) return false;
      return !DateTime(f.year, f.month, f.day).isBefore(now);
    }).toList();
    matches.sort((a, b) => DateTime(a.year, a.month, a.day)
        .compareTo(DateTime(b.year, b.month, b.day)));
    return matches.isEmpty ? null : matches.first;
  }

  bool get careerHasMatchToday {
    final clubId = careerPlayer?.clubId;
    if (clubId == null) return false;
    return fixtures.any((f) => !f.played &&
        f.year == state.year && f.month == state.month && f.day == state.day &&
        (f.homeClubId == clubId || f.awayClubId == clubId));
  }

  /// The career calendar cannot skip an unplayed player fixture. This is the
  /// hard gate that prevents a user from advancing past match day and leaving
  /// an interactive fixture stranded in the past.
  bool get canAdvanceSimulationDay => !careerHasMatchToday;

  /// Moves a completed football season through the remaining calendar
  /// days and lands exactly on 1 July of the next campaign. It is intentionally
  /// player-triggered: the device clock never advances the career.
  int finishCompletedSeason() {
    if (!leagueEngine.isSeasonComplete()) {
      throw StateError('Sezon nie został jeszcze zakończony.');
    }

    var advanced = 0;
    while (!(state.month == 7 && state.day == 1)) {
      advanceDay();
      advanced++;
      if (advanced > 370) {
        throw StateError('Nie udało się bezpiecznie zamknąć sezonu.');
      }
    }
    return advanced;
  }

  // ==========================================================
  // DATA
  // ==========================================================

  /// The football calendar is controlled exclusively by player actions.
  /// Device clock / wall-clock time never advances the career.
  bool get isSimulationStart =>
      state.year == state.season && state.month == 7 && state.day == 24;

  /// Advances exactly one in-game day. This is the only normal way to move
  /// the career calendar forward; finishing a match does not consume a day.
  DailySimulationReport advanceSimulationDay() => advanceDay();

  String get currentDate {
    return state.dateString;
  }

  // ==========================================================
  // SEZON
  // ==========================================================

  int get currentSeason {
    return state.season;
  }

  // ==========================================================
  // OKNO TRANSFEROWE - LATO
  // ==========================================================

  int get currentAbsoluteDay => worldEngine.absoluteDayForDate(state.year, state.month, state.day);

  bool get summerTransferWindow {
    return state.transferWindowSummer;
  }

  // ==========================================================
  // OKNO TRANSFEROWE - ZIMA
  // ==========================================================

  bool get winterTransferWindow {
    return state.transferWindowWinter;
  }

  // ==========================================================
  // KLUBY EKSTRAKLASY
  // ==========================================================

  List<Club> get leagueClubs {
    final id = careerPlayer?.clubId == null ? 'pol_ek' : clubs.firstWhere((c) => c.id == careerPlayer!.clubId).leagueId;
    return clubs.where((club) => club.leagueId == id).toList();
  }

  // ==========================================================
  // KLUBY DOSTĘPNE NA START KARIERY
  // ==========================================================

  List<Club> get careerStartClubs => clubs.toList();

  // ==========================================================
  // WYBÓR KLUBU NA START KARIERY
  // ==========================================================

  void startCareerAtClub(
    String clubId,
  ) {
    if (careerPlayer == null) {
      throw StateError(
        'Najpierw utwórz zawodnika.',
      );
    }

    assignPlayerToClub(clubId);
  }

  // ==========================================================
  // AKTUALNY KLUB ZAWODNIKA
  // ==========================================================

  Club? get careerClub {
    if (careerPlayer == null) {
      return null;
    }

    final clubId = careerPlayer!.clubId;

    if (clubId == null) {
      return null;
    }

    for (final club in clubs) {
      if (club.id == clubId) {
        return club;
      }
    }

    return null;
  }

  // ==========================================================
  // CZY ZAWODNIK MA KLUB
  // ==========================================================

  bool get hasCareerClub {
    return careerPlayer?.clubId != null;
  }
}
