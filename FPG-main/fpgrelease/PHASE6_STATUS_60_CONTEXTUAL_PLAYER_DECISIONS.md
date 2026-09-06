# Phase 6 — 60 CONTEXTUAL PLAYER DECISIONS

## Status
IMPLEMENTED

## Gameplay change
The live 2D match now selects the ball carrier's action from contextual football information instead of a mostly positional random branch.

Inputs include:
- player attributes: pace, shooting, passing, dribbling, defending, physical;
- pressure from the nearest opponent;
- forward space;
- distance to goal / field zone;
- score state and match minute urgency;
- whether the team is leading or chasing;
- team/role context and best teammate availability.

Actions:
PASS / CARRY / DRIBBLE / CROSS / SHOOT / RECYCLE / CLEAR.

## Authority boundary
This is runtime gameplay decision logic only. It does not own the official league result, fixture reconciliation, RNG seed contract, save transaction, or career result commit.

## Compatibility
Match2DPlayer receives football attributes from Player when constructed. Existing callers remain compatible because defaults are provided.

## Validation limitation
Flutter/Dart SDK is not available in the execution environment, therefore Flutter analyzer/build/device tests are not claimed as executed.
