# PHASE 6 — 58 TEAM PLAYSTYLE AI

Status: DONE
Date: 2026-09-01

## Goal
Teams now have different on-pitch identities derived from the club's existing `managerStyle` instead of sharing one universal attack/defence behaviour.

## Styles
- possession — slower circulation, shorter support and controlled forward risk;
- direct — higher tempo and earlier vertical attacks;
- counter — deeper baseline and aggressive attacks into space;
- wing — wider positioning and stronger wing/cross sequences;
- high_press — stronger midfield pressure;
- low_block — deeper compact positioning and reduced forward risk;
- balanced — neutral baseline.

Legacy `youth`, `stars` and `physical` styles remain valid and are translated to possession, high-press and direct behaviour respectively, preserving old saves while giving those teams a distinct on-pitch identity.

## Integration
`MatchScreen` passes both club manager styles to `Match2DEngine`. The live AI uses them for width, tempo, pressing, forward risk and defensive depth. `MatchSituationEngine` also weights the type of attack generated.

The club remains the source of tactical identity. No second persisted truth is created.

## Safety
Official score/result, RNG ownership, fixture reconciliation, save/load transactions and league commits are unchanged.

## Verification
Static source review completed. Flutter/Dart SDK is not available in this environment; `flutter analyze`, `flutter test`, APK build and device runtime validation were not executed.
