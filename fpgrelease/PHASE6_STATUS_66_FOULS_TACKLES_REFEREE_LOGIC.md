# Phase 6 — 66 FOULS, TACKLES & REFEREE LOGIC

Implemented a runtime referee layer between physical challenges and restarts.

## Added
- `RefereeEngine` with foul probability based on proximity, speed, defending, stamina, physicality and attacker control.
- Clean challenge / foul outcomes.
- Free kick vs penalty restart.
- Yellow, second-yellow and rare straight-red outcomes.
- Advantage logic for selected continuing attacks.
- Existing official-result, reconciliation and save ownership remain untouched.

## Integration
`Match2DEngine._maybeMatchIncident()` now asks `RefereeEngine` for the consequence of a challenge instead of directly rolling cards and restart types.

## Verification
A focused `referee_engine_test.dart` was added. Flutter/Dart CLI is not available in this environment, so Flutter analyzer/device tests are not claimed as executed.
