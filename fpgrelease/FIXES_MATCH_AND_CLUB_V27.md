# V27 — Match realism, player stats and club centre

## Naprawione
- profil zawodnika otrzymuje rzeczywisty występ z interaktywnego meczu 2D zamiast drugiego losowania statystyk po meczu;
- płynniejszy ruch 2D: klatki animacji są oddzielone od zegara minutowego, więc piłka i zawodnicy nie przeskakują co minutę;
- przerwa po 45. minucie z komunikatem i zmianą stron;
- auty, rzuty rożne, faule, żółte/czerwone kartki, kontuzje i zmiany są generowane w przebiegu meczu;
- ławka rezerwowych jest częścią stanu meczu, a zmiennicy faktycznie pojawiają się na boisku;
- po 90. minucie działa doliczony czas i komunikat końcowy;
- statystyki 2D zawierają rożne, kartki i faule i są przekazywane do wyniku interaktywnego meczu;
- każdy zawodnik świata otrzymuje własny numer koszulki; starsze zapisy są automatycznie migrowane, a duplikaty w klubie są naprawiane;
- wybór numeru kariery nie pozwala już zająć numeru używanego przez innego zawodnika;
- dodano osobną zakładkę **KLUB** z podstawowym składem, ławką, zawodnikami poza kadrą, OVR, budżetem, reputacją, finansami, trenerem i informacjami klubowymi;
- mini-gry otrzymały czytelniejsze oznaczenia wariantu/ryzyka oraz większy panel akcji.

## Uwaga techniczna
W środowisku wykonawczym tego pakietu nie był dostępny Flutter/Dart SDK, więc nie można było uruchomić `flutter analyze` ani testów widgetowych. Zmiany zostały sprawdzone statycznie pod kątem struktur i zgodności wywołań.
