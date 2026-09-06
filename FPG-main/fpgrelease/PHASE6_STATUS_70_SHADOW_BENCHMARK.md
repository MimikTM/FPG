# FPG — Phase 6 / Etap 70
## SHADOW MATCH BENCHMARK — COMPLETED

### Cel
Etap 70 jest warstwą walidacyjną dla nowego gameplayowego wyniku. Uruchamia macierz pełnych meczów AI-vs-AI w `gameplayResultAuthority=true`, bez zmiany oficjalnych wyników ligi, reconciliation, save ani career world.

### Zakres
- 7 stylów: possession, direct, counter, wing_play, high_press, low_block, balanced.
- Pełna macierz home × away.
- Konfigurowalna liczba meczów na parę stylów.
- Deterministyczny strumień seedów.
- Agregacja: gole, 0:0, W/R/P, strzały, obrony, faule, kartki, rożne, zmiany.
- Infrastructure gate: każdy mecz musi dojść do full time i zachować zgodność score ↔ GameplayResultAuthority ledger.

### Zasada bezpieczeństwa
Benchmark jest `shadow-only`: nie publikuje wyniku do fixture/world state i nie zastępuje legacy league authority. To celowe — najpierw mierzymy stabilność i rozkłady, dopiero potem wykonujemy migrację oficjalnego wyniku.

### Nowy kod
- `lib/simulation/shadow_match_benchmark.dart`
- `test/shadow_match_benchmark_test.dart`

### Kryterium etapu
Etap 70 jest zaliczony technicznie, gdy macierz kończy wszystkie mecze, ledger jest spójny, a ten sam seed daje te same agregaty.

Balans piłkarski nie ma jeszcze twardego progu PASS/FAIL — dane z benchmarku są wejściem do kolejnej fazy strojenia.
