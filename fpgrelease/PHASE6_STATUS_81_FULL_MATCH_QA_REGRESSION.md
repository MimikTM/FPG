# Phase 6 / Etap 81 — FULL-MATCH QA / REGRESSION

Status: **IN PROGRESS — static QA completed, runtime QA blocked by missing Flutter/Dart SDK**

## Zakres wykonanej kontroli

### 1. Gameplay result authority
- `Match2DEngine.create(... gameplayResultAuthority: true)` zeruje ledger przy rozpoczęciu meczu.
- `targetHomeGoals` / `targetAwayGoals` są wymuszane na `null` w trybie authority.
- harmonogramowane gole i końcowe `_forceSyncFinalScore()` są wyłączone w trybie authority.
- każdy `_registerGoal()` aktualizuje `GameplayResultAuthority`.
- `GameplayCareerIntegration` odrzuca niespójny ledger.

### 2. Granica gameplay → kariera
- zakończony mecz jest wymagany przed utworzeniem `MatchResult`.
- wynik, statystyki meczowe i eventy są kopiowane z zakończonego gameplayu.
- adapter nie ma dostępu do fixture/table/save, więc nie tworzy drugiego źródła zapisu.

### 3. Commit
- `MatchScreen` korzysta wyłącznie z `commitGameplayMatchResult()` dla nowego meczu.
- `MatchScreen` nie wywołuje już legacy `reconcileInteractiveFixtureResult()`.
- `commitGameplayMatchResult()` nie uruchamia `matchEngine.simulate()`.
- fixture, tabela i career statistics są aktualizowane w jednej ścieżce.
- ponowny commit tego samego wyniku jest idempotentny.

### 4. Replay
- rozegrany wcześniej fixture pozostaje replayem.
- replay otrzymuje zapisany wynik jako target legacy.
- replay nie wykonuje ponownego commitowania do tabeli.

### 5. Statyczna spójność pakietu
- 228 plików Dart w `lib/` + `test/`.
- brak wykrytych brakujących importów względnych.
- brak wykrytych nierównych nawiasów klamrowych w szybkim audycie strukturalnym.
- kluczowe punkty migracji 80/80 są obecne.

## Znaleziona i poprawiona usterka

`MatchScreen` przekazywał wcześniej nullable `PlayerMatchPerformance?` do `List<PlayerMatchPerformance>`, co było potencjalnym błędem kompilacji Dart.

Poprawka:
- performance zawodnika jest pobierane do lokalnej zmiennej,
- do `GameplayCareerIntegration` trafia pusta lista albo lista zawierająca wyłącznie nie-null performance.

## Dodany test regresyjny

`test/phase6_full_gameplay_result_regression_test.dart`

Test pokrywa:
1. start meczu w `gameplayResultAuthority`,
2. brak target score,
3. rozegranie pełnego meczu 2D,
4. spójność gameplay ledger ↔ final score,
5. konwersję do `MatchResult`,
6. pojedynczy commit do fixture + tabeli,
7. zapis wyniku w `resultSnapshot`,
8. `validateLeagueIntegrity()`,
9. idempotencję drugiego commitu.

## Blokada QA runtime

Nie uruchomiono `flutter test`, `flutter analyze` ani builda urządzeniowego, ponieważ środowisko nie zawiera Flutter/Dart SDK.

Dlatego **nie oznaczamy Etapu 81 jako PASS**. Obecny status to:

**STATIC QA: PASS**
**RUNTIME QA: BLOCKED**
**RELEASE: NOT YET READY**

## Kryteria wejścia do Etapu 82

Po uzyskaniu środowiska Flutter/Dart należy wykonać minimum:
- `flutter analyze`
- wszystkie testy `flutter test`
- pełny test gameplay → MatchResult → fixture → tabela → save/load
- replay już rozegranego fixture
- double-open / double-commit
- save/load po meczu
- kilka pełnych meczów z różnymi wynikami
- kontrolę, że tabela po meczu odpowiada dokładnie fixture/resultSnapshot.

Dopiero po przejściu tych testów można zamknąć Etap 81 i wejść w **82 — FINAL POLISH & STABILIZATION**.
