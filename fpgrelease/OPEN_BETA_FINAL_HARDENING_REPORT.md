# FPG — Open Beta Final Hardening / A-Z Audit

Date: 2026-09-02

## Scope

This pass targets the complete source package with emphasis on:

- Next Day / daily simulation stability
- season rollover
- save/load corruption boundaries
- autonomous world simulation
- degraded rosters / orphaned player references
- 2D match situation generation
- release startup/audio resilience
- league/table integrity

## Fixes applied

### 1. Next Day integrity gate
`GameEngine.advanceDay()` now performs a full post-tick simulation integrity check.
It verifies calendar bounds, player/club graph integrity, league/fixture consistency and career-fixture chronology.

### 2. Calendar hardening
`GameState.fromJson()` now type-checks numeric/bool fields and clamps malformed calendar values to a valid date, including leap-year February.
This prevents malformed legacy saves from reaching `days[month - 1]` or invalid `DateTime` states.

### 3. Season transition guard
New-season generation now fails with a controlled `StateError` if the career league has fewer than two clubs instead of generating an unusable fixture set.

### 4. Orphaned performance protection
Autonomous and legacy match engines no longer crash when a saved performance references a player who has since retired/been removed.
If all performance rows are orphaned, scorer assignment safely returns without `random.nextInt(0)`.

### 5. Degraded 2D match protection
`MatchSituationEngine` now handles a side with no valid opponent or no teammate without calling `.first`/`.reduce` on an empty list.
This protects the match loop against malformed/degraded squads and extreme red-card states.

### 6. Season overview protection
A stale career club reference no longer crashes the season overview screen; the UI returns a safe empty-data presentation.

### 7. Startup/audio hardening
Startup initialization is now inside the guarded application zone.
Audio initialization and volume operations are best-effort and cannot prevent the game from launching if a platform audio backend fails.

### 8. Open Beta diagnostics
Next Day exceptions are recorded as `next_day_error` in the local beta diagnostics file while the UI remains alive and informs the tester.

## Static audit

- Dart source files: 230
- Relative-import audit: no missing relative imports detected in the prior Phase 81 audit.
- Required release assets: present.
- Flutter/Dart runtime: unavailable in this environment.

## Important limitation

The following cannot be honestly marked PASS here because Flutter/Dart SDK is not installed:

- `flutter pub get`
- `flutter analyze`
- `flutter test --coverage --reporter expanded`
- `flutter build apk --debug`
- real-device gameplay
- Android/iOS performance and lifecycle QA

## Required final device gate

On a machine with Flutter installed, run:

```text
flutter pub get
flutter analyze
flutter test --coverage --reporter expanded
flutter build apk --debug
```

Then manually verify at minimum:

1. New Career → first Next Day.
2. Every career match day → play match → Full Time → Next Day.
3. 30+ consecutive simulation days.
4. At least one transfer window.
5. June 30 → July 1 season transition.
6. Save → kill app → load → continue.
7. Replay a played fixture.
8. Open/close Career Home repeatedly around Next Day.
9. Disable/enable audio and change volume.
10. Run one long career for several seasons.

## Release recommendation

The source package is hardened substantially for Open Beta, especially around the previously requested Next Day failure class. Runtime/device verification remains mandatory before publishing an APK to external testers.
