# PHASE 5 — MATCH INTRO 45

Status: **DONE — implementation pass**

## Cel
Match Intro jest teraz prawdziwą fazą przedmeczową, a nie tylko statycznym nagłówkiem. Oficjalny zegar i symulacja nie startują, dopóki prezentacja nie dobiegnie końca.

## Sekwencja
1. MATCHDAY — stadion / atmosfera / transmisja
2. THE TEAMS — gospodarze vs goście
3. LINEUP — wejście zawodników
4. KICKOFF — sędzia gotowy
5. LIVE — przekazanie sterowania do meczu

## Integracja
- `Match2DEngine` pozostaje źródłem prawdy.
- `PitchGame` pozostaje warstwą prezentacyjną.
- Intro blokuje tick meczu na ok. 4,8 s.
- Po intro startuje właściwy timer meczu.
- Istniejąca obsługa halftime, eventów, minigier i finalizacji wyniku pozostaje bez zmian.
- Intro jest skalowalne i nie wymaga osobnego route/screen.

## Następny krok
**46 — Lineup Presentation**: prezentacja XI na żywej murawie, numery, pozycje, kapitan i płynne przejście do kickoff.
