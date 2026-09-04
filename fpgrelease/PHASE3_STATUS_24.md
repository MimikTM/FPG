# FPG — Phase 3 / Stage 24 — Separate Interactive Mini-Game Scene

## Completed
- Replaced the match mini-game AlertDialog presentation with a dedicated full-screen route.
- Added a lightweight scene transition so the mini-game reads as a gameplay moment rather than an application dialog.
- Preserved the existing MiniGameEngine contract: the mini-game produces execution quality; the match engine remains authoritative for the football outcome.
- Preserved all existing interaction types: shot drag, dribble drag, and timing taps for pass/tackle/save.
- Added a dedicated gameplay header, stage indicator, instruction area, full-size interaction arena, and bottom feedback area.
- Added a safe cancel path that resolves the current stage with zero rather than leaving the match paused indefinitely.
- Existing result presentation after the scene remains unchanged.

## Phase 3 status
- 24 Separate interactive scene: DONE
- 25 Shot 2.0 standalone scene: NEXT
- 26 Pass 2.0 standalone scene: TODO
- 27 Dribble 2.0 standalone scene: TODO
- 28 Tackle 2.0 standalone scene: TODO
- 29 Goalkeeper 2.0 standalone scene: TODO
- 30 Contextual camera: TODO
- 31 Real-time feedback: partially present, needs dedicated pass

## Validation
- Static source inspection performed.
- Flutter/Dart toolchain is not assumed in this environment; no analyze/build claim is made.
