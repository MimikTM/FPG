# Phase 6 — Etap 76: Attacking Runs & Off-Ball Intelligence

Status: COMPLETED ✅

## Cel
Rozszerzyć gameplay o kontekstowe ruchy bez piłki. Zawodnik nie podąża już wyłącznie za statycznym targetem formacji: wybiera intencję ruchu zależną od roli, stylu, wolnej przestrzeni, linii obrony i pozycji partnera z piłką.

## Implementacja
- `lib/models/attacking_run.dart`
  - `AttackingRunType`: depth, channel, overlap, underlap, support, decoy, recovery.
  - snapshot telemetry dla Home/Away.
- `lib/simulation/attacking_run_engine.dart`
  - decyzje o kierunku i typie biegu,
  - różnicowanie ról (napastnik, skrzydłowy, wahadłowy/full-back, playmaker, false nine),
  - szukanie wolnego kanału,
  - separacja od partnerów,
  - wpływ stylu gry i pilności sytuacji.
- `Match2DEngine`
  - integracja targetów ruchu bez piłki z istniejącym `PlayerMovementEngine`,
  - telemetryka intencji biegowych.
- `FullMatchSimulationResult`
  - ekspozycja `attackingRuns`.

## Ochrona architektury
- brak zmiany oficjalnego wyniku ligi,
- brak zmian reconciliation/save/career state,
- gameplay result authority nadal pozostaje opt-in,
- istniejący movement engine pozostaje właścicielem przyspieszenia i hamowania.
