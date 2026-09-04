# FPG Open Beta — Compile/CI Hardening Pass

## Trigger
GitHub Actions run on Flutter 3.35.7 reached `flutter pub get`, then
`flutter analyze` failed with 151 analyzer issues (including compile errors).

## Fixed compile blockers
- Match cinematic score fields now use `homeGoals` / `awayGoals`.
- Cinematic overlay is publicly reusable by `PitchGame`.
- Fixed procedural animation locals being referenced before declaration.
- Fixed Vector2 -> Offset conversion for ball trail rendering.
- Fixed numeric `clamp()` values passed where doubles are required.
- Fixed invalid `Colors.white45`.
- Added missing PlayerPosition / PlayerRole imports.
- Added missing `dart:async` import for `unawaited`.
- Fixed Match2D pass-target call signature.
- Fixed undefined `pressure`, `t`, and `dir` references.
- Fixed `Random` constructor incorrectly marked const.
- Fixed integer-to-double calibration closures.
- Updated tests to use `flutter_test`, package imports, current Player API,
  and current PlayerRole enum.
- Fixed gameplay authority test top-level executable statement.
- Added missing `PlayerMatchPerformance` import in the migration regression test.

## Next Day / long-run
The Open Beta long-run test now exercises the real gameplay-authority path:
Match2D -> GameplayCareerIntegration -> commitGameplayMatchResult ->
finalizeCareerMatchDay, rather than the legacy reconciliation path.

## CI
Added `.github/workflows/build_fpg_apk.yml`:
- discovers nested `pubspec.yaml`
- creates Android platform files if absent
- sets Android app label to FPG
- pub get
- launcher icon generation
- flutter analyze
- flutter test
- release APK build
- verifies and uploads `FPG-OpenBeta.apk`

## Verification limitation
Flutter 3.35.7 is available in GitHub Actions, but the local analysis
environment used for this patch does not contain the Flutter/Dart SDK.
Therefore the final runtime/build gate must be confirmed by the next GitHub
Actions run.
