import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/core/game_engine.dart';
import 'package:fpg/core/game_state.dart';
import 'package:fpg/database/world_save.dart';
import 'package:fpg/models/player.dart';

void main() {
  test('career save remains valid after club selection and contract confirmation', () async {
    final engine = GameEngine(
      state: GameState(year: 2026, month: 7, day: 24, season: 2026),
    );
    final club = engine.clubs.first;

    engine.createPlayer(
      firstName: 'Jan',
      lastName: 'Testowy',
      nationality: 'Polska',
      age: 18,
      height: 178,
      position: PlayerPosition.winger,
      pace: 60, shooting: 60, passing: 60, dribbling: 60,
      defending: 60, physical: 60, initialOverall: 60,
    );
    engine.assignPlayerToClub(club.id);
    expect(await WorldSave.save(engine), isTrue);

    engine.configureCareerContract(years: 3, weeklySalary: 250, shirtNumber: 27);
    expect(await WorldSave.save(engine), isTrue);

    expect(await engine.loadWorld(), isTrue);
    expect(engine.careerPlayer, isNotNull);
    expect(engine.careerPlayer!.contract, isNotNull);
    expect(engine.careerPlayer!.contract!.weeklySalary, 250);
    expect(engine.careerPlayer!.contract!.yearsRemaining, 3);
  });
}
