# FPG — Phase 5 / Stage 52 — Referee Presentation

Status: DONE (static integration)

## What was added
- `lib/graphics/match_referee_director.dart`
- presentation-only referee director and Flame component
- referee follows the ball during normal play using an offset support line
- referee reframes toward fouls, cards, injuries, halftime and fulltime
- whistle pulse on disciplinary/stoppage events
- arm/gesture presentation
- yellow/red card visual based on authoritative event description
- broadcast label state (`FOUL`, `YELLOW CARD`, `RED CARD`, `STOPPAGE`, `HALF TIME`, `FULL TIME`)

## Integration
`PitchGame` now feeds authoritative `Match2DEvent` values to `MatchRefereeDirector` and renders `RefereeComponent` on the pitch.

No match state, score, clock, RNG, save/load or transaction logic is mutated by the referee layer.

## Validation
Flutter/Dart SDK is not available in the build environment, so `flutter analyze` / `flutter build` were not run here. Integration was checked statically.
