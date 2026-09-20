# FPG 0.8.5v — AUDIO CUSTOMIZATION

Podmiana muzyki i SFX nie wymaga zmiany kodu, jeśli zachowasz nazwy plików.

## Muzyka

`assets/audio/music/`

- `menu_music.wav` — ekran startowy/menu
- `career_music.wav` — muzyka kariery (przygotowana do użycia w kolejnych ekranach)
- `match_music.wav` — ekran meczu

## SFX

`assets/audio/sfx/`

- `ui_click.wav` — kliknięcia
- `ui_success.wav` — sukces / udana akcja
- `ui_error.wav` — błąd / nieudana akcja
- `countdown.wav` — countdown / wejście w akcję
- `goal.wav` — gol
- `ball_kick.wav` — strzał / kontakt z piłką
- `crowd.wav` — reakcja stadionu

## Jak podmienić

1. Przygotuj własny plik audio.
2. Nadaj mu dokładnie taką samą nazwę jak plik, który zastępujesz.
3. Wgraj go do odpowiedniego folderu `assets/audio/...`.
4. Zastąp stary plik.
5. Zbuduj APK.

Nie zmieniaj nazw plików ani ścieżek, jeśli chcesz uniknąć zmian w Dart.

## Głośność

Ustawienia gry → AUDIO:

- Muzyka 0–100%
- SFX 0–100%

Wartości są zapisywane lokalnie.

## Ważne

Nie dodawaj bardzo długich plików SFX. Muzyka może być długa i jest odtwarzana w pętli. SFX powinny być krótkie.
