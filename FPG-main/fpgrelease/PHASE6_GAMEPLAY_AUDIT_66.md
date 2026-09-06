# Phase 6 Gameplay Audit — 66

## Authority
- RefereeEngine is runtime-only.
- It does not own official score or persistence.
- Existing SetPieceEngine remains responsible for restart execution intent.

## Gameplay chain
challenge -> referee decision -> foul/no foul -> card -> advantage/free kick/penalty -> restart

## Safety
- Existing save transaction and fixture reconciliation are unchanged.
- Card state remains on Match2DPlayer runtime state.
