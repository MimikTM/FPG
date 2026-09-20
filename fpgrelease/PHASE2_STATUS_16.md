# FPG — PHASE 2 / ETAP 16 — PASSING ANIMATION 2.0

Status: IMPLEMENTED

## Zakres
- Kontynuacja istniejącego systemu animacji z Phase 1; bez tworzenia drugiego silnika meczu.
- Pass/cross dostaje osobną sekwencję: plant foot → backswing → release → follow-through.
- Kierunek podania jest pobierany z pozycji drugiego zawodnika, gdy `secondaryPlayerId` istnieje; fallback wykorzystuje facing zawodnika.
- Cross ma nieco dłuższą sekwencję i mocniejszy ruch kontaktowy.
- Ramiona i noga reagują na fazę podania.
- Dodany `_PassRelease` jako krótki, kontekstowy efekt kontaktu.
- `Match2DEngine` nadal pozostaje źródłem prawdy dla pozycji, posiadania i wyniku.

## Dodatkowa poprawka
Przeniesiono obliczenie `ballXpx/ballYpx` przed blok kamery w `PitchGame`, aby uniknąć odwołania do lokalnych zmiennych przed ich deklaracją.

## Status Phase 2
- 16. Passing Animation 2.0 — DONE
- 17. Shooting Animation 2.0 — EXISTING FROM PHASE 1, needs final Phase 2 pass
- 18. Tackling Animation 2.0 — existing foundation, needs final Phase 2 pass
- 19. Receiving Animation 2.0 — existing foundation, needs final Phase 2 pass
- 20. Dribbling Animation 2.0 — existing foundation, needs final Phase 2 pass
- 21. Goalkeeper Animation 2.0 — existing foundation, needs final Phase 2 pass
- 22. Goal Sequence — not started as Phase 2 final sequence
- 23. Substitution Sequence — not started

## Verification
Flutter/Dart toolchain is not guaranteed in the current environment, so no `flutter analyze` or device build is claimed. The changed Dart source was reviewed statically for the introduced symbols and declaration ordering.
