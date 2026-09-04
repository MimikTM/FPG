import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/beta_diagnostics.dart';
import '../core/game_engine.dart';

/// Reliable offline persistence for the whole career.
///
/// Saves are serialized so a rapid sequence of auto-saves cannot overwrite or
/// delete a file while another save is still writing it. Every successful
/// snapshot is written to a temporary file, flushed, then promoted to the
/// primary save. The previous primary save is kept as a rollback copy.
class WorldSave {
  static const int schemaVersion = 18;
  static const String fileName = 'fpg_world_save.json';
  static const String backupFileName = 'fpg_world_save.json.bak';
  static const String tempFileName = 'fpg_world_save.json.tmp';

  static Future<void> _saveQueue = Future<void>.value();

  static Future<Directory> _directory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      // Flutter test/desktop environments may not register the platform
      // path_provider implementation. Keep persistence testable and offline
      // by falling back to a dedicated temporary directory. Android/iOS use
      // the real application documents directory above.
      final fallback = Directory('${Directory.systemTemp.path}/fpg_save');
      await fallback.create(recursive: true);
      return fallback;
    }
  }

  static Future<File> _file() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}/$fileName');
  }

  static Future<File> _backupFile() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}/$backupFileName');
  }

  static Future<File> _tempFile() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}/$tempFileName');
  }

  static Future<bool> save(GameEngine engine) {
    final completer = Completer<bool>();

    // Always append to the queue, even after an earlier failure. This is
    // important when the user presses save several times in quick succession.
    _saveQueue = _saveQueue.catchError((_) {}).then((_) async {
      try {
        final ok = await _write(engine);
        if (!completer.isCompleted) completer.complete(ok);
      } catch (_) {
        if (!completer.isCompleted) completer.complete(false);
      }
    });

    return completer.future;
  }

  static Future<bool> _write(GameEngine engine) async {
    File? temp;
    try {
      final file = await _file();
      final backup = await _backupFile();
      temp = await _tempFile();

      final payload = <String, dynamic>{
        'schemaVersion': schemaVersion,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'gameState': engine.state.toJson(),
        'players': engine.players.map((p) => p.toJson()).toList(),
        'clubs': engine.clubs.map((c) => c.toJson()).toList(),
        'worldEngine': engine.worldEngine.toJson(),
        'careerPlayer': engine.careerPlayer == null ? null : _careerJson(engine.careerPlayer!),
        'careerMatchSnapshot': engine.careerMatchSnapshot,
        'fixtures': engine.fixtures.map((f) => {
          'round': f.round,
          'homeClubId': f.homeClubId,
          'awayClubId': f.awayClubId,
          'year': f.year,
          'month': f.month,
          'day': f.day,
          'played': f.played,
          'homeGoals': f.homeGoals,
          'awayGoals': f.awayGoals,
          'resultSnapshot': f.resultSnapshot,
        }).toList(),
      };

      final encoded = jsonEncode(payload);
      await temp.writeAsString(encoded, flush: true);

      // Never replace a valid save with a partially written file.
      if (await file.exists()) {
        await file.copy(backup.path);
      }

      try {
        // Both files live in the same application directory, so rename is the
        // preferred atomic promotion. Some Android filesystem providers can
        // still reject rename after a delete; keep a safe copy fallback so a
        // valid career is not reported as failed just because promotion was
        // unsupported.
        if (await file.exists()) await file.delete();
        await temp.rename(file.path);
        temp = null;
      } on FileSystemException {
        await temp.copy(file.path);
        await temp.delete();
        temp = null;
      }
      return true;
    } catch (e, st) {
      // Previously this exception was discarded entirely (`catch (_)`), so
      // "save failed" gave no clue why — not even in the beta diagnostics
      // file the app already collects for every other crash. Record it the
      // same way so a real cause shows up in fpg_beta_diagnostics.jsonl
      // instead of a dead end.
      unawaited(BetaDiagnostics.record(
        type: 'save_write_error',
        message: e.toString(),
        stack: st.toString(),
      ));
      try {
        if (temp != null && await temp.exists()) await temp.delete();
      } catch (_) {}
      return false;
    }
  }

  static Future<bool> hasSave() async {
    final snapshot = await load();
    return snapshot != null;
  }

  static Future<bool> deleteSave() async {
    try {
      final file = await _file();
      final backup = await _backupFile();
      final temp = await _tempFile();
      for (final f in [file, backup, temp]) {
        if (await f.exists()) await f.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> load() async {
    final primary = await _file();
    final backup = await _backupFile();

    final primaryMap = await _readValid(primary);
    if (primaryMap != null) return primaryMap;

    // If the app was killed during a replacement, restore from the last good
    // snapshot rather than silently starting a new career.
    return _readValid(backup);
  }

  static Future<Map<String, dynamic>?> _readValid(File file) async {
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final versionRaw = map['schemaVersion'];
      final version = versionRaw is num ? versionRaw.toInt() : 1;
      if (version > schemaVersion) return null;
      if (map['gameState'] is! Map) return null;

      // V18 migration: older saves may not contain optional transaction
      // sections. Normalize them here so LOAD always sees the same shape.
      map['schemaVersion'] = schemaVersion;
      map['careerMatchSnapshot'] ??= <String, dynamic>{};
      map['worldEngine'] ??= <String, dynamic>{};
      map['fixtures'] ??= <dynamic>[];
      if (map['fixtures'] != null && map['fixtures'] is! List) return null;
      return map;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> exists() async {
    final file = await _file();
    final backup = await _backupFile();
    return await file.exists() || await backup.exists();
  }

  static Map<String, dynamic> _careerJson(dynamic p) => {
    'id': p.id, 'firstName': p.firstName, 'lastName': p.lastName, 'nationality': p.nationality,
    'age': p.age, 'height': p.height, 'position': p.position.name, 'overall': p.overall,
    'potential': p.potential, 'pace': p.pace, 'shooting': p.shooting, 'passing': p.passing,
    'dribbling': p.dribbling, 'defending': p.defending, 'physical': p.physical, 'clubId': p.clubId,
    'shirtNumber': p.shirtNumber, 'fatigue': p.fatigue, 'fitness': p.fitness, 'form': p.form,
    'morale': p.morale, 'happiness': p.happiness,
    'fame': p.fame, 'reputation': p.reputation, 'fanSupport': p.fanSupport, 'mediaPressure': p.mediaPressure,
    'marketability': p.marketability, 'transferPull': p.transferPull,
    'sponsorInterest': p.sponsorInterest, 'sponsorTier': p.sponsorTier, 'sponsorIncome': p.sponsorIncome,
    'agentAttention': p.agentAttention, 'interviewInvites': p.interviewInvites, 'mediaAppearances': p.mediaAppearances,
    'shirtDemand': p.shirtDemand, 'coachPressure': p.coachPressure, 'fanMoments': p.fanMoments,
    'clubInterestLevel': p.clubInterestLevel, 'marketingValue': p.marketingValue, 'commercialEvents': p.commercialEvents,
    'managerRelationship': p.managerRelationship, 'teamRelationship': p.teamRelationship,
    'agentId': p.agentId, 'agentInfluence': p.agentInfluence, 'transferRequest': p.transferRequest,
    'internationalCaps': p.internationalCaps, 'internationalGoals': p.internationalGoals,
    'internationalAssists': p.internationalAssists, 'nationalCallUps': p.nationalCallUps,
    'lastNationalCallUpYear': p.lastNationalCallUpYear, 'wageExpectation': p.wageExpectation,
    'appearanceBonus': p.appearanceBonus, 'goalBonus': p.goalBonus, 'assistBonus': p.assistBonus,
    'trophyBonus': p.trophyBonus, 'releaseClause': p.releaseClause, 'contractYearsRemaining': p.contractYearsRemaining,
    'loanFeeExpectation': p.loanFeeExpectation, 'guaranteedMinutesExpectation': p.guaranteedMinutesExpectation,
    'buyoutClauseExpectation': p.buyoutClauseExpectation, 'loanFromClubId': p.loanFromClubId,
    'loanUntilDay': p.loanUntilDay, 'loanStartedDay': p.loanStartedDay, 'loanStartMinutes': p.loanStartMinutes,
    'loanWageShare': p.loanWageShare, 'loanBuyoutClause': p.loanBuyoutClause,
    'developmentSeasonYear': p.developmentSeasonYear, 'seasonStartOverall': p.seasonStartOverall,
    'inMatchSquad': p.inMatchSquad, 'isStarter': p.isStarter, 'isRegularStarter': p.isRegularStarter,
    'squadStatus': p.squadStatus, 'careerAppearances': p.careerAppearances, 'careerGoals': p.careerGoals,
    'careerAssists': p.careerAssists,
    'contract': p.contract == null ? null : p.contract!.toJson(),
    'matchStats': p.matchStats.toJson(),
  };
}
