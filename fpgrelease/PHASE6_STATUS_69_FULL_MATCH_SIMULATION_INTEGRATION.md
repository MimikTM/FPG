# Phase 6 — Etap 69: FULL MATCH SIMULATION INTEGRATION

Status: ✅ COMPLETED

## Cel
Uruchomić cały mecz 90+ minut w trybie headless, bez UI i bez kopiowania wyniku z fixture. Match2DEngine pozostaje jedynym źródłem gameplayu.

## Co dodano
- `FullMatchSimulation` — cienki runner AI-vs-AI do pełnego meczu.
- `FullMatchSimulationResult` — wynik, czas, eventy oraz podstawowe metryki do walidacji.
- deterministyczny signature eventów dla testów seed/RNG.
- kontrolę `maxTicks`, aby wadliwa pętla nie blokowała procesu.
- walidację spójności `GameplayResultAuthority` po końcu meczu.

## Zmiana migracyjna
W `gameplayResultAuthority=true` oba `target*Goals` są teraz zerwane (`null`). Nie istnieje już ukryty cel domyślny z fixture.

Mini-game strzału również nie ma sztucznego limitu `target + 1` w authority mode. Legacy mode zachowuje dotychczasowy bezpieczny limit.

## Nienaruszone
- oficjalna ścieżka ligi / reconciliation,
- save/load kariery,
- legacy Match2D (`gameplayResultAuthority=false`),
- PitchGame jako warstwa prezentacji.

## Kryterium etapu
Etap 69 nie zmienia jeszcze oficjalnych fixture'ów na gameplay authority. Dostarcza pełny runner i obserwowalny kontrakt walidacyjny, który można wykorzystać do wielomeczowego shadow testu przed migracją produkcyjną.
