# FPG V25.1 — Open Beta Hardening Pass

## Pass status

**Implemented:** persistence hardening and exact fixture restoration.

## Changes

### 1. Exact fixture restoration after SAVE/LOAD

`GameEngine.fixtures` is now a mutable collection. A save restores the complete persisted fixture list, including:

- round
- home/away club
- exact calendar date
- played state
- score
- result snapshot

This prevents a save from a later season from being merged into the constructor's original 2026 schedule.

### 2. Crash-resistant world save

`WorldSave` is now schema version 13 and writes to a temporary file first. The previous known-good save is copied to:

`fpg_world_save.json.bak`

If the primary save is corrupt or missing, load automatically attempts the backup.

### 3. Save validation

The loader rejects malformed top-level JSON, incompatible future schema versions, missing `gameState`, and malformed fixture containers instead of treating them as a valid career.

### 4. Existing career-match transaction remains intact

The previous V25 transaction boundary remains:

`day -> pre-match -> interactive Match 2D -> fixture commit -> career consequences -> world tick -> season maintenance`

The interactive fixture is still protected by the idempotency key set.

## Verification available in this environment

- Critical Dart files have balanced delimiters.
- Fixture restoration no longer depends on the constructor's default season.
- The project archive was rebuilt after the changes.

Flutter/Dart SDK is not installed in this execution environment, so `flutter analyze`, `flutter test`, and a release build could not be executed here. The APK reported by the user as already building is therefore not re-certified by this environment.

## Next queue

1. Real device SAVE -> force close -> LOAD test.
2. SAVE on a pending match day -> restart -> play Match 2D -> continue day.
3. Full season simulation and league-integrity audit.
4. 3-season long run.
5. 10-season long run.
6. Only after stability passes: world-content expansion and UI polish.
