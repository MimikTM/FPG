# Phase 6 — Etap 75: Goalkeeper AI & Goalkeeper Positioning

Status: COMPLETED

## Zakres
- Dedykowany `GoalkeeperEngine` ocenia ustawienie, pokrycie kąta, reakcję i sytuacje 1-na-1.
- Bramkarz otrzymuje własny target ruchu: głębokość zależną od położenia piłki i korektę boczną.
- Jakość bramkarza wpływa na prawdopodobieństwo obrony w modelu strzału.
- Logika pozostaje gameplay-only i nie zmienia oficjalnego wyniku ligi, reconciliation ani save.

## Bezpieczeństwo
Legacy target-result mode pozostaje domyślny. Gameplay result authority pozostaje opt-in.
