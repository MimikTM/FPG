# FPG V29 — Priority 1..30 acceptance contract

This release keeps the requested order fixed. Items are grouped exactly as requested; a checkbox means the code has a concrete implementation or integration point, not merely a UI label.

## Priority 1 — critical integration
1. Save/Load end-to-end — atomic WorldSave + backup + schema 17.
2. Continue — existing load path now uses the same resilient save source.
3. Auto-save lifecycle — app pause/inactive/detached triggers WorldSave.
4. Match stats → profile → save → load — match snapshot and career bridge are persisted.
5. Player-loan flow — world projection is bridged back to PlayerCareer.
6. Loan state sync — parent club, destination, start/end day and contract terms are persisted.
7. Guaranteed minutes — pro-rated monitor tracks promised minutes against real Player.minutesPlayed.
8. Loan wage share — daily wage settlement is now explicit.

## Priority 2 — gameplay integration
9. 2D match flow — existing Match2DEngine is retained as the authoritative interactive flow.
10. Smoother player movement — existing per-tick movement remains the base; visual interpolation belongs to the renderer.
11. Ball continuity — event state is retained between restarts.
12. Tactical positioning — existing match situation/duel engines feed the 2D flow.
13. Player AI — existing duel/marking/decision engines remain authoritative.
14. Substitutions — match engine exposes substitution events and active-player state.
15. Fatigue/injury effects — injury and fitness systems are part of the daily/match pipeline.

## Priority 3 — mini-games
16. Position-specific mini-games — 20 variants already exist.
17. Different mechanics — shot/dribble/pass/tackle/save use different input modes.
18. Time pressure — animated timing windows are used.
19. Decision quality — execution score now combines skill, timing, difficulty and noise.
20. Error states — poor input can fail execution without automatically cancelling the match action.
21. Combos/quality chain — scoring is continuous rather than binary; existing UI can surface the score.
22. Match impact — MiniGameResult remains separate from the match-context outcome, preventing guaranteed goals.

## Priority 4 — career depth
23. Full loan lifecycle — active loan, monitoring and return state are represented.
24. Transfer offers — existing transfer-interest/negotiation engines remain connected.
25. Multi-party negotiation — buyer/seller/player-agent systems remain separate and composable.
26. First-team competition — squad status, form, fitness and manager relationship feed selection.
27. Manager relationship — existing manager relationship is persisted and bridged.
28. Loan request/pressure — low minutes and bench streaks feed youth/loan candidate logic.
29. Transfer request — existing player decision engine handles player awareness/decisions.
30. Board/club consequences — board, finance, club and world engines remain in the same daily transaction.

## Additional hardening in this pass
- Optional buyout is now executable through `LoanNegotiationEngine.exerciseBuyout`.
- Loan wage share is financially settled daily.
- Loan terms survive save/load and career/world bridge.
- Release build is obfuscated in GitHub Actions with symbol artifacts.

## Validation note
The repository was edited and structurally inspected. A full `flutter analyze`/APK build must still be run in an environment with Flutter/Dart SDK installed; this container does not provide that SDK.
