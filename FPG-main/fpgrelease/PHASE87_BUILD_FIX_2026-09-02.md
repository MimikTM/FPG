# FPG — GitHub APK Build Fix

## Log analyzed
The GitHub Actions run reached `flutter analyze` successfully. `flutter pub get` passed. Android platform generation and launcher icon generation passed.

`flutter analyze` reported 16 issues: 12 infos and 4 errors.

## Blocking errors fixed

1. `lib/graphics/pitch_game.dart:883`
   - `shotRelease` was referenced before declaration.
   - Moved `shotRelease` calculation before `shootKick`.

2. `lib/graphics/pitch_game.dart:1049`
   - `tacklePlant` was referenced but undefined.
   - Added a bounded tackle-plant animation factor.

3. `lib/screens/match_screen.dart:1031`
   - A non-const `Colors.white.withValues(...)` call was inside a `const Text` constructor.
   - Removed the invalid `const` from that widget.

4. `lib/simulation/ball_physics_engine.dart:88`
   - `max()`/`min()` numeric inference produced `num` where `double` was required.
   - Normalized the bounce calculation to `double` and used `1.0` for the upper bound.

## Clean analyzer improvements

Also cleaned the analyzer infos found in the same run:
- removed unused Cupertino import;
- fixed overridden resize parameter naming;
- removed unused pitch fields;
- annotated `_BallDot.height` override;
- made `_BallDot._trail` final;
- removed empty `_ReplayBanner.update` override;
- replaced deprecated `withOpacity` with `withValues(alpha: ...)` in stadium atmosphere.

## Verification

- Workflow YAML parsed successfully with Ruby YAML parser.
- `pubspec.yaml` was found by the workflow at `./fpg84` in the supplied GitHub log.
- Flutter runtime itself is not installed in the local analysis environment, so final `flutter analyze/test/build` execution after these source fixes still has to be performed by GitHub Actions.
