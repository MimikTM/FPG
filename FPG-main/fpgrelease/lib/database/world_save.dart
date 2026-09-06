import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../core/beta_diagnostics.dart';
import '../core/game_engine.dart';
/// Reliable offline persistence for the whole career.
class WorldSave {
  static const int schemaVersion = 18;
  static const String fileName = 'fpg_world_save.json';
  static const String backupFileName = 'fpg_world_save.json.bak';
  static const String tempFileName = 'fpg_world_save.json.tmp';
  static Future<void> _saveQueue = Future<void>.value();

  /// Requests legacy Android storage access before the first career save.
  ///
  /// The actual save is kept in the app-private documents directory, so the
  /// permission is NOT required for persistence. On newer Android versions
  /// generic storage permission is no longer applicable; in that case this
  /// method simply returns and saving continues normally.
  static Future<bool> prepareStorageAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.storage.request();
      return status.isGranted || status.isLimited || status.isRestricted;
    } catch (_) {
      // Never block a career save because an optional legacy permission API
      // is unavailable. App-private storage does not need this permission.
      return true;
    }
  }

  static Future<Directory> _directory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      final fallback = Directory(
        '${Directory.systemTemp.path}/fpg_save',
      );
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
    _saveQueue = _saveQueue.catchError((_) {}).then((_) async {
      try {
        final ok = await _write(engine);
        if (!completer.isCompleted) {
          completer.complete(ok);
        }
      } catch (_) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
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
        'careerPlayer': engine.careerPlayer == null
            ? null
            : _careerJson(engine.careerPlayer!),
        'careerMatchSnapshot': engine.careerMatchSnapshot,
        'fixtures': engine.fixtures
            .map(
              (f) => {
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
              },
            )
            .toList(),
      };
      final encoded = jsonEncode(payload);
      await temp.writeAsString(
        encoded,
        flush: true,
      );
      if (await file.exists()) {
        await file.copy(backup.path);
      }
      try {
        if (await file.exists()) {
          await file.delete();
        }
        final tempFile = temp!;
        await tempFile.rename(file.path);
        temp = null;
      } on FileSystemException {
        final tempFile = temp!;
        await tempFile.copy(file.path);
        await tempFile.delete();
        temp = null;
      }
      return true;
    } catch (e, st) {
      unawaited(
        BetaDiagnostics.record(
          type: 'save_write_error',
          message: e.toString(),
          stack: st.toString(),
        ),
      );
      try {
        final tempFile = temp;
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
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
        if (await f.exists()) {
          await f.delete();
        }
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
    if (primaryMap != null) {
      return primaryMap;
    }
    return _readValid(backup);
  }
  static Future<Map<String, dynamic>?> _readValid(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      final decoded = jsonDecode(
        await file.readAsString(),
      );
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      final versionRaw = map['schemaVersion'];
      final version = versionRaw is num
          ? versionRaw.toInt()
          : 1;
      if (version > schemaVersion) {
        return null;
      }
      if (map['gameState'] is! Map) {
        return null;
      }
      map['schemaVersion'] = schemaVersion;
      map['careerMatchSnapshot'] ??= <String, dynamic>{};
      map['worldEngine'] ??= <String, dynamic>{};
      map['fixtures'] ??= <dynamic>[];
      if (map['fixtures'] is! List) {
        return null;
      }
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
        'id': p.id,
        'firstName': p.firstName,
        'lastName': p.lastName,
        'nationality': p.nationality,
        'age': p.age,
        'height': p.height,
        'position': p.position.name,
        'overall': p.overall,
        'potential': p.potential,
        'pace': p.pace,
        'shooting': p.shooting,
        'passing': p.passing,
        'dribbling': p.dribbling,
        'defending': p.defending,
        'physical': p.physical,
        'clubId': p.clubId,
        'shirtNumber': p.shirtNumber,
        'fatigue': p.fatigue,
        'fitness': p.fitness,
        'form': p.form,
        'morale': p.morale,
        'happiness': p.happiness,
        'fame': p.fame,
        'reputation': p.reputation,
        'fanSupport': p.fanSupport,
        'mediaPressure': p.mediaPressure,
        'marketability': p.marketability,
        'transferPull': p.transferPull,
        'sponsorInterest': p.sponsorInterest,
        'sponsorTier': p.sponsorTier,
        'sponsorIncome': p.sponsorIncome,
        'agentAttention': p.agentAttention,
        'interviewInvites': p.interviewInvites,
        'mediaAppearances': p.mediaAppearances,
        'shirtDemand': p.shirtDemand,
        'coachPressure': p.coachPressure,
        'fanMoments': p.fanMoments,
        'clubInterestLevel': p.clubInterestLevel,
        'marketingValue': p.marketingValue,
        'commercialEvents': p.commercialEvents,
        'managerRelationship': p.managerRelationship,
        'teamRelationship': p.teamRelationship,
        'agentId': p.agentId,
        'agentInfluence': p.agentInfluence,
        'transferRequest': p.transferRequest,
        'internationalCaps': p.internationalCaps,
        'internationalGoals': p.internationalGoals,
        'internationalAssists': p.internationalAssists,
        'nationalCallUps': p.nationalCallUps,
        'lastNationalCallUpYear': p.lastNationalCallUpYear,
        'wageExpectation': p.wageExpectation,
        'appearanceBonus': p.appearanceBonus,
        'goalBonus': p.goalBonus,
        'assistBonus': p.assistBonus,
        'trophyBonus': p.trophyBonus,
        'releaseClause': p.releaseClause,
        'contractYearsRemaining': p.contractYearsRemaining,
        'loanFeeExpectation': p.loanFeeExpectation,
        'guaranteedMinutesExpectation':
            p.guaranteedMinutesExpectation,
        'buyoutClauseExpectation':
            p.buyoutClauseExpectation,
        'loanFromClubId': p.loanFromClubId,
        'loanUntilDay': p.loanUntilDay,
        'loanStartedDay': p.loanStartedDay,
        'loanStartMinutes': p.loanStartMinutes,
        'loanWageShare': p.loanWageShare,
        'loanBuyoutClause': p.loanBuyoutClause,
        'developmentSeasonYear':
            p.developmentSeasonYear,
        'seasonStartOverall': p.seasonStartOverall,
        'inMatchSquad': p.inMatchSquad,
        'isStarter': p.isStarter,
        'isRegularStarter': p.isRegularStarter,
        'squadStatus': p.squadStatus,
        'careerAppearances': p.careerAppearances,
        'careerGoals': p.careerGoals,
        'careerAssists': p.careerAssists,
        'contract': p.contract?.toJson(),
        'matchStats': p.matchStats.toJson(),
      };
}
