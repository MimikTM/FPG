# FPG Phase 1 — Status 07

## Completed in this iteration
- Presentation-side ball velocity smoothing derived from authoritative simulation movement.
- Ball momentum now drives the visual travel stretch and motion trail.
- First-touch contact now emits a dedicated contact mark/flash.
- Ball presentation state receives smoothed velocity and contact flash from PitchGame.
- Existing animation/state architecture remains intact.

## Important boundary
The Match2DEngine remains authoritative. This iteration does not replace the simulation with a separate physics engine. It improves the presentation layer so the ball reads as a moving object with momentum.

## Phase 1 status
1. Player animation system — DONE
2. Better movement — DONE
3. Ball physics — IN PROGRESS (presentation momentum; authoritative physics still next)
4. Player-ball collision/contact — IN PROGRESS (first-touch presentation; physical collision still next)
5. Animation state machine — DONE
6. Camera system — TODO
7. Improved AI movement — TODO

## Next
- Add a bounded, deterministic ball-contact model around pass/shot/reception events without taking authority away from Match2DEngine.
- Then build the gameplay camera and contextual framing.
