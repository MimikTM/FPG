# Phase 6 — etap 71: Gameplay Balance & Match Statistics Calibration

Status: COMPLETED ✅

Etap 71 adds a non-invasive calibration layer on top of the Phase 70 shadow benchmark.

## Added
- `MatchBalanceCalibration` with explicit statistical bands for goals, shots,
  fouls, cards, corners and scoreless matches.
- Recommendations when a metric falls outside its current calibration band.
- `Match2DEngine.expectedGoals` diagnostic accumulator from the contextual shot model.
- `FullMatchSimulationResult.expectedGoals` telemetry field.
- Unit tests for healthy and intentionally unbalanced profiles.

## Safety
No league fixture result, reconciliation, save transaction or career-world
source of truth is changed. Calibration is diagnostic/shadow-only.

## Current calibration bands
- goals: 1.6–3.8 / match
- shots: 6–22 / match
- fouls: 4–24 / match
- cards: 0.2–7 / match
- corners: 2–14 / match
- scoreless matches: 3%–30%

These are engineering guardrails, not claims of official real-world averages.
They are intentionally broad and should be tightened after larger benchmark runs.
