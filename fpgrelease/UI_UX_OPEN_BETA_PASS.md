# FPG — UI/UX Open Beta Pass

## Zakres

Ten pass porządkuje główną ścieżkę użytkownika bez zmiany istniejącej identyfikacji wizualnej FPG.

### Zrobione
- dodany ekran startowy marki FPG przy zimnym uruchomieniu,
- splash trwa ok. 1,8 s i płynnie przechodzi do menu,
- branding: `FPG` / `Football Player Game` / `creator by mEmmor`,
- zastąpiono stary ekran techniczny normalnym menu głównym,
- jedna czytelna hierarchia: Nowa kariera / Kontynuuj / Ustawienia,
- zachowano istniejącą paletę granat + cyan + fiolet oraz karty/glow/hero gradient,
- ujednolicono podstawowe style przycisków Material,
- poprawiono AppBar i badge FPG w Career Home,
- ograniczono hard-coded białe teksty w Career Home, aby tryb jasny nie wyglądał jak osobny produkt.

## Główna ścieżka

`Splash -> Menu główne -> Nowa kariera -> Stworzenie zawodnika -> Wybór klubu -> Career Home`

lub

`Splash -> Menu główne -> Kontynuuj -> Save Load -> Career Home`

## Cel UX

Gracz powinien po uruchomieniu od razu rozumieć:
1. czym jest FPG,
2. jak rozpocząć karierę,
3. jak wrócić do zapisanej kariery,
4. gdzie zmienić wygląd aplikacji.

## Następny krok QA

Po podpięciu Flutter SDK uruchomić:

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Następnie sprawdzić splash, menu, przejście Nowa kariera/Kontynuuj oraz Career Home na prawdziwym urządzeniu.
