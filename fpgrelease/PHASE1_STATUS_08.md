# FPG — PHASE 1 STATUS 08

## Completed
- Added authoritative match-space ball velocity to Match2DState.
- Added a small parabolic ball-flight height for pass/cross travel.
- Ball flight now has a readable trajectory while the receiving player remains the authoritative target.
- Added ball height to the Flame presentation layer.
- Ball shadow now contracts/fades with lift, while the ball itself rises during flight.
- Velocity is reset cleanly on possession/restart snaps.
- Existing player animation/contact systems remain unchanged.

## Important boundary
This is the first real ball-flight physics layer, but it is intentionally bounded: it does not yet introduce free-form collision resolution, bounce, deflection or autonomous ball ownership changes. Match2DEngine remains the source of truth.

## Next
1. Real player-ball contact resolution.
2. Deflection/rebound on tackle/block.
3. Controlled first-touch direction.
4. Then gameplay camera and AI movement pass.
