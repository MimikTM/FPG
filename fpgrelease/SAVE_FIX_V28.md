# FPG V28 — zapis kariery / Continue

- Zapis świata jest serializowany: szybkie autozapisy nie nadpisują się równolegle.
- Snapshot jest zapisywany do pliku tymczasowego z `flush: true`, a dopiero potem promowany do głównego save.
- Poprzedni poprawny zapis pozostaje w `.bak`.
- Przy uszkodzonym/brakującym głównym pliku `Continue` automatycznie próbuje backupu.
- Zapis wykonywany jest po utworzeniu zawodnika, wyborze klubu i zatwierdzeniu kontraktu.
- `CareerHomeScreen` wykonuje autozapis po przejściu aplikacji w tło / stan inactive / detached oraz przy opuszczaniu ekranu kariery.
- Save schema podniesione do 16; starsze zapisy są nadal akceptowane przez loader.
- Naprawiono błąd składni w bannerze przerwy 45' w `match_screen.dart`.

Uwaga: środowisko robocze nie zawiera Flutter/Dart SDK, więc lokalne `flutter analyze`/`flutter build` nie mogło zostać wykonane tutaj.
