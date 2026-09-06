# PHASE 6 — 59 DEFENSIVE LINE & TRANSITIONS

Status: IMPLEMENTED
Date: 2026-09-01

## Goal
Turnover behaviour now has an explicit runtime transition layer instead of treating every defensive frame as the same generic positioning problem.

## Added
- `MatchTransitionPhase`: inPossession, loss, counterPress, retreat, settledDefence, recovery.
- `MatchTransitionProfile`: style-aware line height, compactness, cover, runner tracking, counter-press and retreat speed.
- Runtime transition phase is derived from current and previous ball ownership and stored only in `Match2DState` as derived runtime state.
- Defensive line height now reacts to the team's style and transition phase.
- Counter-press can temporarily increase pressure after loss of possession.
- Retreat increases defensive compactness and runner tracking.
- Settled defence prioritises compactness/cover rather than chasing the ball.

## Authority
No change to official result, RNG ownership, fixture reconciliation, save/load transactions or career commit flow.

## Verification
Added focused unit coverage for style differentiation and retreat detection. Flutter/Dart SDK availability must still be verified in a real Flutter environment before claiming `flutter test` or device validation.
