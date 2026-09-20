# FPG 0.8.5v — DIAMOND PASS 3 — UI/UX POLISH

## Cel
Doszlifowanie istniejącego interfejsu bez zmiany jego tożsamości wizualnej.

## Zmiany
- Globalne przejścia ekranów: płynne przejście zamiast domyślnego twardego skoku na Androidzie.
- Płynna animacja zmiany jasny/ciemny motyw.
- Spójny splash/feedback materiałowy przez InkSparkle.
- Ujednolicony wygląd progress indicatorów z akcentem FPG.
- Lepsza typografia globalna: body/display korzystają z aktywnego koloru tekstu.
- Delikatny scrollbar zgodny z mobilnym UI.
- Animowane wejście głównego ekranu FPG (fade + subtelny slide), bez zmiany układu menu.
- Zachowana obecna paleta dark/light, karty, gradient hero i istniejąca nawigacja.

## Bezpieczne ograniczenie zakresu
Nie przebudowywano ekranów na siłę i nie dodawano fikcyjnego audio, którego silnik nie obsługuje. Ten pass jest czysto prezentacyjny i nie powinien zmieniać logiki kariery, save/load ani symulacji świata.

## Walidacja
- Przejrzano strukturę `lib/` i wszystkie ekrany obecne w paczce.
- Sprawdzono balans nawiasów w plikach Dart.
- Flutter/Dart nie są dostępne w tym środowisku wykonawczym, więc nie wykonano lokalnego `flutter analyze`/`flutter test`.

## Następny krok
P6 — tutorial interaktywny + UX pierwszej kariery. Następnie P7 audio/SFX i finalny QA APK.
