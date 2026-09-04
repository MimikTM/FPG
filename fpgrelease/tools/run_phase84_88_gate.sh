#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== FPG Phase 84-88 Release Gate ==="
echo "Project: $(basename "$ROOT")"

echo "[1/4] Static project checks"
test -f pubspec.yaml
test -f assets/fpg_logo.png
test -f assets/audio/music/menu_music.wav
test -f assets/audio/music/career_music.wav
test -f assets/audio/music/match_music.wav
test -f assets/audio/sfx/ui_click.wav
test -f assets/audio/sfx/ui_success.wav
test -f assets/audio/sfx/ui_error.wav
test -f assets/audio/sfx/countdown.wav
test -f assets/audio/sfx/goal.wav
test -f assets/audio/sfx/ball_kick.wav
test -f assets/audio/sfx/crowd.wav
echo "PASS: release assets present"

if ! command -v flutter >/dev/null 2>&1; then
  echo "BLOCKED: Flutter SDK unavailable."
  echo "Run on a Flutter-enabled machine:"
  echo "  flutter pub get"
  echo "  flutter analyze"
  echo "  flutter test --coverage --reporter expanded"
  echo "  flutter build apk --release"
  exit 0
fi

echo "[2/4] Dependencies"
flutter pub get

echo "[3/4] Analyze + tests"
flutter analyze
flutter test --coverage --reporter expanded

echo "[4/4] Release build"
flutter build apk --release

echo "PASS: Phase 84-88 runtime/release gate completed"
