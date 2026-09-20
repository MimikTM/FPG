# Phase 6 — 68 GAMEPLAY RESULT AUTHORITY

## Goal
Introduce a controlled migration from pre-calculated fixture targets to an emergent gameplay-owned score.

## Implementation
- Added `GameplayResultAuthority`, an isolated runtime score ledger.
- Added `Match2DEngine.create(..., gameplayResultAuthority: true)` opt-in mode.
- In authority mode the engine does **not** copy target goals into `Match2DState`.
- Scheduled-goal materialization is disabled in authority mode.
- Final-score force synchronization is disabled in authority mode.
- Every actual `_registerGoal()` updates the gameplay ledger.
- Added `gameplayResultSnapshot` consistency check.

## Compatibility
Default mode remains legacy-safe (`false`). Existing league fixtures, reconciliation and save transactions are untouched.

## Migration rule
This phase is deliberately opt-in. Before making gameplay authority the default, compare long-run score distributions and reconcile the official fixture transaction at the boundary only.

## Tooling
Flutter/Dart SDK is not available in this environment; analyze/test/device build are not claimed as executed.
