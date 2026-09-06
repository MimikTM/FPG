import 'package:shared_preferences/shared_preferences.dart';

/// Global gameplay settings. Values are persisted locally and do not require
/// Android storage permissions.
enum MiniGameDifficulty {
  easy,
  medium,
  hard,
  simulation,
}

extension MiniGameDifficultyX on MiniGameDifficulty {
  String get label {
    switch (this) {
      case MiniGameDifficulty.easy:
        return 'ŁATWY';
      case MiniGameDifficulty.medium:
        return 'ŚREDNI';
      case MiniGameDifficulty.hard:
        return 'TRUDNY';
      case MiniGameDifficulty.simulation:
        return 'SYMULACYJNY';
    }
  }

  String get description {
    switch (this) {
      case MiniGameDifficulty.easy:
        return 'Duże okna czasowe i łagodna presja.';
      case MiniGameDifficulty.medium:
        return 'Standardowy poziom dla większości graczy.';
      case MiniGameDifficulty.hard:
        return 'Węższe okna i większa kara za błędy.';
      case MiniGameDifficulty.simulation:
        return 'Trudność zależna od poziomu ligi i zawodnika.';
    }
  }
}

class GameSettings {
  GameSettings._();

  static MiniGameDifficulty difficulty = MiniGameDifficulty.medium;
  static bool autoSave = true;
  static bool vibrations = true;
  static bool confirmDecisions = true;
  static bool tutorialCompleted = false;
  static double musicVolume = 70;
  static double sfxVolume = 80;

  static const _difficultyKey = 'fpg_difficulty';
  static const _autoSaveKey = 'fpg_auto_save';
  static const _vibrationsKey = 'fpg_vibrations';
  static const _confirmKey = 'fpg_confirm_decisions';
  static const _tutorialKey = 'fpg_tutorial_completed';
  static const _musicVolumeKey = 'fpg_music_volume';
  static const _sfxVolumeKey = 'fpg_sfx_volume';

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getInt(_difficultyKey) ?? MiniGameDifficulty.medium.index;
      difficulty = MiniGameDifficulty.values[
          raw.clamp(0, MiniGameDifficulty.values.length - 1).toInt()];
      autoSave = prefs.getBool(_autoSaveKey) ?? true;
      vibrations = prefs.getBool(_vibrationsKey) ?? true;
      confirmDecisions = prefs.getBool(_confirmKey) ?? true;
      tutorialCompleted = prefs.getBool(_tutorialKey) ?? false;
      musicVolume = (prefs.getDouble(_musicVolumeKey) ?? 70).clamp(0, 100).toDouble();
      sfxVolume = (prefs.getDouble(_sfxVolumeKey) ?? 80).clamp(0, 100).toDouble();
    } catch (_) {
      // Defaults remain usable in tests and unsupported environments.
    }
  }

  static Future<void> setDifficulty(MiniGameDifficulty value) async {
    difficulty = value;
    await _writeInt(_difficultyKey, value.index);
  }

  static Future<void> setAutoSave(bool value) async {
    autoSave = value;
    await _writeBool(_autoSaveKey, value);
  }

  static Future<void> setVibrations(bool value) async {
    vibrations = value;
    await _writeBool(_vibrationsKey, value);
  }

  static Future<void> setConfirmDecisions(bool value) async {
    confirmDecisions = value;
    await _writeBool(_confirmKey, value);
  }

  static Future<void> setTutorialCompleted(bool value) async {
    tutorialCompleted = value;
    await _writeBool(_tutorialKey, value);
  }

  static Future<void> setMusicVolume(double value) async {
    musicVolume = value.clamp(0, 100).toDouble();
    await _writeDouble(_musicVolumeKey, musicVolume);
  }

  static Future<void> setSfxVolume(double value) async {
    sfxVolume = value.clamp(0, 100).toDouble();
    await _writeDouble(_sfxVolumeKey, sfxVolume);
  }

  static Future<void> _writeInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (_) {}
  }

  static Future<void> _writeDouble(String key, double value) async {
    try { final prefs = await SharedPreferences.getInstance(); await prefs.setDouble(key, value); } catch (_) {}
  }

  static Future<void> _writeBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }
}
