# FPG — PHASE 5 / 49 BROADCAST CAMERA DIRECTOR

Status: DONE (static integration)
Date: 2026-09-01

## Cel
Upgrade the existing pitch camera from a simple event zoom into a dedicated presentation-only broadcast camera director.

## Implemented
- Added `lib/graphics/broadcast_camera_director.dart`.
- Normal play follows the authoritative match ball with soft interpolation.
- GOAL focuses the event player for a longer celebration frame.
- SHOT / SAVE tighten the frame briefly.
- FOUL / CARD / INJURY create a short contextual focus.
- SUBSTITUTION gets a dedicated wider presentation hold.
- HALFTIME / FULLTIME return to a neutral broadcast framing.
- Camera state is isolated from `Match2DEngine`; no simulation values depend on camera output.
- Player positions used for focus are copied into presentation-space coordinates each frame.
- Existing `PitchGame` effects, goal celebrations, substitutions, ball presentation and event handling remain intact.

## Matchday flow
MATCH INTRO -> LINEUP -> KICKOFF -> LIVE -> HALFTIME -> 2ND HALF -> FULL TIME -> POST MATCH

The camera director is active during LIVE presentation and reacts to authoritative match events without becoming another source of truth.

## Validation
- Source integration inspected statically.
- Flutter/Dart runtime build was not available in the execution environment, so no runtime build claim is made.

## Next
50 — MATCH PRESENTATION DIRECTOR: unify camera, broadcast HUD, crowd, audio, transitions and match-state presentation into one orchestration layer.
