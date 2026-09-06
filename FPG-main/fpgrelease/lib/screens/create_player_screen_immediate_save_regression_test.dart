import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fpg/core/game_engine.dart';
import 'package:fpg/core/game_state.dart';
import 'package:fpg/database/world_save.dart';
import 'package:fpg/models/player.dart';

/// Odtwarza DOKŁADNIE sekwencję z `create_player_screen.dart::createPlayer()`:
///
///   1. engine.createPlayer(...)
///   2. await engine.saveWorld()   <-- w tym momencie zawodnik NIE MA jeszcze
///      klubu (`clubId == null`) ani kontraktu (`contract == null`).
///
/// Wszystkie dotychczasowe testy w tym repo (`career_start_save_regression_test`,
/// `save_load_transaction_integration_test`, itd.) wywołują
/// `engine.assignPlayerToClub(club.id)` PRZED pierwszym zapisem, więc ta
/// dokładna sekwencja z ekranu "ROZPOCZNIJ KARIERĘ" nigdy nie była pokryta
/// testem — a to właśnie ten moment zgłasza użytkownikom
/// "Nie udało się zapisać kariery. Spróbuj ponownie.".
void main() {
  test('zapis od razu po stworzeniu zawodnika, przed przypisaniem do klubu', () async {
    final engine = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );

    engine.createPlayer(
      firstName: 'Jan',
      lastName: 'Testowy',
      nationality: 'Polska',
      age: 18,
      height: 178,
      position: PlayerPosition.winger,
      pace: 60,
      shooting: 60,
      passing: 60,
      dribbling: 60,
      defending: 60,
      physical: 60,
      initialOverall: 60,
    );

    final ok = await WorldSave.save(engine);

    if (!ok) {
      // Ten sam plik diagnostyczny, do którego world_save.dart pisze na
      // urządzeniu (fpg_beta_diagnostics.jsonl). Jeśli test tu padnie,
      // log poniżej pokaże dokładny wyjątek i stack trace zamiast samego
      // "false" — czyli dokładnie to, czego brakowało w komunikacie
      // widocznym dla gracza.
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/fpg_beta_diagnostics.jsonl');
        if (await file.exists()) {
          final lines = await file.readAsLines();
          // ignore: avoid_print
          print('--- fpg_beta_diagnostics.jsonl (ostatnie wpisy) ---');
          for (final line in lines.reversed.take(5).toList().reversed) {
            final decoded = jsonDecode(line);
            // ignore: avoid_print
            print(decoded);
          }
        } else {
          // ignore: avoid_print
          print('Brak pliku diagnostycznego pod: ${file.path}');
        }
      } catch (e) {
        // ignore: avoid_print
        print('Nie udało się odczytać diagnostyki: $e');
      }
    }

    expect(ok, isTrue, reason: 'Zapis zaraz po utworzeniu zawodnika (bez klubu) nie powiódł się.');
  });
}
