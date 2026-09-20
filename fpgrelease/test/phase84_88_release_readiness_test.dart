import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const requiredAssets = <String>[
    'assets/fpg_logo.png',
    'assets/audio/music/menu_music.wav',
    'assets/audio/music/career_music.wav',
    'assets/audio/music/match_music.wav',
    'assets/audio/sfx/ui_click.wav',
    'assets/audio/sfx/ui_success.wav',
    'assets/audio/sfx/ui_error.wav',
    'assets/audio/sfx/countdown.wav',
    'assets/audio/sfx/goal.wav',
    'assets/audio/sfx/ball_kick.wav',
    'assets/audio/sfx/crowd.wav',
  ];

  test('release assets are present', () {
    for (final path in requiredAssets) {
      expect(File(path).existsSync(), isTrue, reason: 'Missing release asset: $path');
    }
  });

  test('pubspec exposes the release assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final path in <String>[
      'assets/fpg_logo.png',
      'assets/audio/music/',
      'assets/audio/sfx/',
    ]) {
      expect(pubspec, contains(path), reason: 'pubspec does not expose $path');
    }
  });

  test('release version is no longer the pre-stabilization 0.8.x build', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: 0.9.0+1'));
    expect(pubspec, isNot(contains('version: 0.8.5+1')));
  });
}
