# FPG 0.8.5v — P4 World Pass

## Wykonane

- 7 lig w seedzie świata:
  - Ekstraklasa — 18 klubów
  - Betclic 1 Liga — 18 klubów
  - Betclic 2 Liga — 18 klubów
  - Betclic 3 Liga — Grupa I — 18 klubów
  - Betclic 3 Liga — Grupa II — 18 klubów
  - Betclic 3 Liga — Grupa III — 18 klubów
  - Betclic 3 Liga — Grupa IV — 18 klubów
- Łącznie: 126 klubów.
- Każdy klub dostaje parametry AI, budżet, reputację, akademię, zarząd, trenera, styl i stabilność.
- Terminarze są generowane automatycznie przez istniejący FixtureGenerator dla każdej grupy.
- WorldEngine został poprawiony tak, aby cztery grupy 3 Ligi nie były traktowane jako jedna liga tylko dlatego, że mają ten sam level.
- Awans/spadek działa między poziomami 1↔2 i 2↔3.
- Zwycięzcy czterech grup 3 Ligi są promowani do 2 Ligi; dwa ostatnie zespoły 2 Ligi są rozdzielane deterministycznie do grup 3 Ligi.
- Wybór klubu pokazuje teraz pełną piramidę zamiast tylko dwóch lig.
- Istniejące save/load nadal opiera się na `leagueId`, więc stare zapisy zachowują kompatybilność tam, gdzie używają istniejących identyfikatorów.

## Źródła składu 2026/27

Skład Ekstraklasy i 1 Ligi został zweryfikowany względem aktualnych zestawień sezonu 2026/27. Betclic 2 Liga została zweryfikowana względem terminarza sezonu 2026/27. 3 Liga jest odwzorowana jako cztery grupy po 18 klubów na potrzeby silnika świata.

## Następny krok

P5 — polish UI/UX bez przebudowy całego interfejsu: stany loading/error/empty, feedback akcji, mikroanimacje, karty, typografia i spójność ekranów.
