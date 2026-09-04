# FPG — Phase 5 / 54 Matchday Audio Director

## Done
- Added `MatchdayAudioDirector` as a presentation-only audio state machine.
- Wired intro, lineup, live, halftime, second half, full time and post-match phases.
- Wired match events to existing SFX: goal, shot/save, foul/card, crowd and phase transitions.
- Kept `Match2DEngine` authoritative; audio never mutates gameplay state.
- Reused the project's existing audio assets, so no new binary assets are required.

## Runtime note
Flutter/Dart SDK availability is environment-dependent; this package was statically integrated but no device runtime build is claimed here.
