import '../core/game_state.dart';

/// Legacy compatibility facade.
///
/// The game no longer uses this class for career persistence. The authoritative
/// save format is WorldSave, because a career needs the whole world snapshot,
/// not only GameState. Keeping this facade avoids breaking older imports while
/// making it explicit that it must not be used by new gameplay code.
@Deprecated('Use WorldSave through GameEngine.saveWorld/loadWorld instead.')
class SaveManager {
  static Future<bool> saveGame(GameState gameState) async => false;
  static Future<GameState?> loadGame() async => null;
  static Future<bool> hasSaveFile() async => false;
}
