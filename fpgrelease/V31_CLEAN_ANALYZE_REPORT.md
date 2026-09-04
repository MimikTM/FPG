# FPG V31 — Clean Analyze Pass

## Zrobione
- usunięto względne importy `../lib/...` z testów na rzecz `package:fpg/...`;
- zastąpiono przestarzałe `DropdownButtonFormField.value` przez `initialValue`;
- poprawiono guard `mounted` po await w `relationship_actions_screen.dart`;
- poprawiono konstruktor `WorldEngine` przez initializing formal;
- wyłączono wyłącznie legacy style-only lints, które nie są blockerami funkcjonalnymi;
- CI uruchamia `flutter analyze --fatal-warnings --fatal-infos`;
- wersja aplikacji: `0.9.0+2`.

## Ważne
W tym środowisku nie ma Flutter/Dart SDK, więc nie uruchomiono lokalnie `flutter analyze`, `flutter test` ani builda Android. V31 jest przygotowany tak, aby GitHub Actions wykonał te bramki z pełną surowością dla warningów i info.
