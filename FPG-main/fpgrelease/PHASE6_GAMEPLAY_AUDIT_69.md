# Phase 6 Gameplay Audit — 69

## Authority
`Match2DEngine` pozostaje właścicielem ruchu, piłki, decyzji, strzałów i goli. `FullMatchSimulation` tylko napędza ticki i zbiera wynik.

## Result integrity
Każdy gol przechodzi przez `_registerGoal()`, który aktualizuje zarówno `Match2DState`, jak i `GameplayResultAuthority`. Po meczu `scoreLedgerConsistent` umożliwia sprawdzenie obu źródeł.

## Determinism
Runner przyjmuje `Random`, a wynik zawiera `deterministicSignature` z minut, typów eventów i zawodników. Ten sam seed może być porównany bez ingerowania w UI.

## Safety
`maxTicks` chroni przed nieskończonym przebiegiem. Legacy mode nadal może używać target goals; authority mode nie otrzymuje target goals.

## Next validation target
Kolejny krok powinien być wielomeczowym shadow benchmarkiem: wiele seedów × style taktyczne, z raportem średnich goli, strzałów, fauli, kartek, rożnych, comebacków, 0:0 oraz rozrzutu wyników. Dopiero po stabilnym benchmarku należy rozważyć włączenie authority dla oficjalnych fixture'ów.
