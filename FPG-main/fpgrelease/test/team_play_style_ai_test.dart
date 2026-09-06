import 'package:flutter_test/flutter_test.dart';
import 'package:fpg/models/team_play_style.dart';

void main() {
  test('style profiles are materially different', () {
    final possession = TeamPlayStyleProfile.fromManagerStyle('possession');
    final direct = TeamPlayStyleProfile.fromManagerStyle('direct');
    final wing = TeamPlayStyleProfile.fromManagerStyle('wing');
    final press = TeamPlayStyleProfile.fromManagerStyle('high_press');
    final low = TeamPlayStyleProfile.fromManagerStyle('low_block');

    expect(possession.tempo, lessThan(direct.tempo));
    expect(direct.forwardRisk, greaterThan(possession.forwardRisk));
    expect(wing.width, greaterThan(possession.width));
    expect(press.pressing, greaterThan(possession.pressing));
    expect(low.defensiveDepth, lessThan(possession.defensiveDepth));
  });

  test('legacy manager styles remain backwards compatible', () {
    expect(TeamPlayStyleProfile.fromManagerStyle('youth').style,
        TeamPlayStyle.balanced);
    expect(TeamPlayStyleProfile.fromManagerStyle('stars').style,
        TeamPlayStyle.balanced);
    expect(TeamPlayStyleProfile.fromManagerStyle('physical').style,
        TeamPlayStyle.balanced);
  });
}
