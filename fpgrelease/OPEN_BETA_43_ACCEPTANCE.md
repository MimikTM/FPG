# FPG Open Beta — Acceptance Pass A–F / 1–43

Ten plik jest checklistą wydania. Każdy punkt ma właściciela testu i kryterium „done”.

## A — RELEASE
1. Android project — CI generuje platformę; przed Play release trzeba zatwierdzić wygenerowany projekt.
2. Release signing — przygotować prywatny keystore poza repo i wstrzyknąć sekrety CI.
3. AAB — CI buduje `flutter build appbundle --release`.
4. Package ID — ustawić docelowy applicationId w wygenerowanym Android projekcie.
5. Versioning — aplikacja ma `0.9.0+1` jako pierwszy Open Beta candidate.
6. Launcher/splash — ikona generowana z `assets/fpg_logo.png`; splash do weryfikacji na urządzeniu.
7. Release obfuscation — `--obfuscate --split-debug-info`; symbole są artefaktem CI.
8. CI analyze — `flutter analyze` jest blokadą workflow.
9. CI test — `flutter test` jest blokadą workflow.
10. CI build — APK i AAB muszą powstać; oba są artefaktami.

## B — SAVE
11. Jeden oficjalny save — `WorldSave` jest jedynym używanym systemem; `SaveManager` pozostawiono wyłącznie jako deprecated compatibility facade.
12. Save migration — schema 18 normalizuje brakujące sekcje opcjonalne.
13. Continue — `loadWorld()` waliduje snapshot transakcyjnie i przywraca karierę.
14. Force-close test — wykonać na fizycznym Androidzie po meczu i po zmianie dnia.
15. Corrupt-save test — uszkodzić primary i sprawdzić automatyczny fallback do `.bak`.
16. Backup restore — primary + backup muszą być obecne po drugim udanym zapisie.
17. Match save/load — wynik meczu, statystyki i fixture muszą przejść przez save/load bez podwójnego naliczenia.

## C — CAREER
18. Pierwszy dzień — utworzenie zawodnika kończy się zapisem.
19. Pierwszy mecz — interaktywny fixture jest jedynym źródłem wyniku dla meczu kariery.
20. Statystyki — występy/minuty/gole/asysty/kartki zapisują się do PlayerMatchStats i profilu.
21. Trening — trening nie może cofnąć save'a ani dnia.
22. Transfer — oferta, decyzja i zmiana klubu muszą przetrwać restart.
23. Wypożyczenie — kandydat z małą liczbą minut może otrzymać wypożyczenie.
24. Powrót z wypożyczenia — `loanUntilDay` zwalnia zawodnika i czyści pola wypożyczenia.
25. Koniec sezonu — awans sezonu nie może duplikować terminarza ani tabeli.

## D — MATCH
26. Płynność 2D — render tick 60 ms; silnik meczu zachowuje zegar niezależnie od renderowania.
27. AI — pozycjonowanie i decyzje muszą być sprawdzone na urządzeniu, nie tylko statycznie.
28. Piłka — brak teleportacji; do finalnego testu potrzebna obserwacja 60 FPS na urządzeniu.
29. Zmiany — zmiany są częścią silnika i wpływają na aktywnych zawodników.
30. Kartki/kontuzje/auty/rożne — wydarzenia są modelowane i zapisują statystyki.
31. Halftime — 45' zatrzymuje mecz, pokazuje przerwę i zmienia strony.
32. Fulltime — doliczony czas i pojedyncza finalizacja fixture.

## E — MINI-GAMES
33. 5 głównych mini-gier — save/pass/tackle/shot/dribble mają różne wejścia.
34. Tutorial — UI musi jasno podpowiadać sterowanie; do finalnego testu manualnego.
35. Difficulty — wynik uwzględnia skill, kontekst i trudność.
36. Feedback — wynik i etap są widoczne; mini-gra ma teraz 2–3 etapy zamiast pojedynczego inputu.
37. Wpływ na mecz — wynik mini-gry trafia do `applyMiniGameOutcome`, a nie tylko do komunikatu.

## F — BETA INFRASTRUCTURE
38. Crash reporting — dodano lokalny `BetaDiagnostics`; przed publiczną betą warto podłączyć zewnętrzny backend crashów.
39. Privacy — lokalny diagnostics nie zbiera danych osobowych; zewnętrzne analytics/crash reporting wymaga osobnej polityki prywatności i konfiguracji.
40. Tester feedback — do wydania należy dodać formularz/kanal zgłoszeń powiązany z numerem wersji.
41. Versioning — `0.9.0+1`; każdy build beta zwiększa build number.
42. Beta release notes — ten plik + changelog wersji powinny być dołączone do dystrybucji.
43. Backup/logowanie błędów — save posiada `.bak`, a błędy aplikacji są lokalnie rejestrowane.

## Definition of Done
Open Beta nie jest „DONE”, dopóki: CI przechodzi analyze + test + APK + AAB, a test na fizycznym Androidzie przechodzi scenariusz nowa kariera → mecz → zapis → force close → Continue → transfer/wypożyczenie → kolejny dzień bez utraty danych.
