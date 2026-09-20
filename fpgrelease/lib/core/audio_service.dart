import 'package:audioplayers/audioplayers.dart';
import 'game_settings.dart';

/// Central audio router. Replace files in assets/audio/music and assets/audio/sfx
/// without changing gameplay code. Keep the filenames or edit constants below.
class FPGAudio {
  FPGAudio._();
  static final AudioPlayer _music = AudioPlayer(playerId: 'fpg_music');
  static final AudioPlayer _sfx = AudioPlayer(playerId: 'fpg_sfx');
  static final AudioPlayer _sfxAlt = AudioPlayer(playerId: 'fpg_sfx_alt');
  static bool _sfxToggle = false;
  static const menuMusic = 'audio/music/menu_music.wav';
  static const careerMusic = 'audio/music/career_music.wav';
  static const matchMusic = 'audio/music/match_music.wav';
  static const click = 'audio/sfx/ui_click.wav';
  static const success = 'audio/sfx/ui_success.wav';
  static const error = 'audio/sfx/ui_error.wav';
  static const countdown = 'audio/sfx/countdown.wav';
  static const goal = 'audio/sfx/goal.wav';
  static const kick = 'audio/sfx/ball_kick.wav';
  static const crowd = 'audio/sfx/crowd.wav';
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _sfx.setReleaseMode(ReleaseMode.release);
      await _sfxAlt.setReleaseMode(ReleaseMode.release);
      await _music.setVolume(GameSettings.musicVolume / 100);
      await _sfx.setVolume(GameSettings.sfxVolume / 100);
      await _sfxAlt.setVolume(GameSettings.sfxVolume / 100);
      _ready = true;
    } catch (_) {
      // Audio is optional presentation. A broken/missing platform audio
      // backend must never block startup or gameplay. playMusic/playSfx have
      // their own best-effort guards as well.
      _ready = false;
    }
  }

  static Future<void> setMusicVolume(double value) async {
    await init();
    try {
      await _music.setVolume(value.clamp(0, 100) / 100);
    } catch (_) {}
  }
  static Future<void> setSfxVolume(double value) async {
    await init();
    try {
      await _sfx.setVolume(value.clamp(0, 100) / 100);
      await _sfxAlt.setVolume(value.clamp(0, 100) / 100);
    } catch (_) {}
  }
  static Future<void> playMusic(String asset) async {
    await init();
    if (GameSettings.musicVolume <= 0) return;
    try { await _music.play(AssetSource(asset)); } catch (_) {}
  }
  static Future<void> stopMusic() async { try { await _music.stop(); } catch (_) {} }
  static Future<void> playSfx(String asset) async {
    await init();
    if (GameSettings.sfxVolume <= 0) return;
    final player = _sfxToggle ? _sfx : _sfxAlt;
    _sfxToggle = !_sfxToggle;
    try { await player.play(AssetSource(asset)); } catch (_) {}
  }
  static Future<void> dispose() async { await _music.dispose(); await _sfx.dispose(); await _sfxAlt.dispose(); _ready = false; }
}
