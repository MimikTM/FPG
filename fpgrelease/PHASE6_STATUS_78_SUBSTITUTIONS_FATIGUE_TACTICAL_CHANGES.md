# PHASE 6 — ETAP 78
## SUBSTITUTIONS, FATIGUE & TACTICAL CHANGES

Status: COMPLETE ✅

### Cel
Połączyć zmęczenie zawodników z decyzjami meczowymi. Zmiany nie są już wyłącznie losowym zdarzeniem w wybranej minucie: silniejszy powód do zmiany wynika z niskiej staminy, sytuacji wyniku i końcowego pościgu za rezultatem.

### Zakres
- stopniowe zużycie `stamina` w runtime,
- większe zużycie dla stylów o wysokiej intensywności i zespołu przegrywającego po 70',
- priorytet zmiany uwzględnia średnią i najniższą staminę,
- przegrywający zespół dostaje dodatkowy bodziec do zmiany w końcowej fazie,
- zachowany limit maksymalnie 3 zmian na zespół w obecnym silniku,
- bramkarz nie jest wybierany do zwykłej zmiany,
- istniejąca ścieżka kontuzji pozostaje kompatybilna.

### Bezpieczna architektura
Etap jest runtime-only. Nie zmienia oficjalnego wyniku ligi, reconciliation, save ani career state. Gameplay authority pozostaje opt-in.
