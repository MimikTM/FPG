# FPG — Phase 6 / 61 — FORMATION & ROLE SYSTEM

## Status
IMPLEMENTED — runtime gameplay layer.

## Goal
Turn the existing positional XI into a tactical 4-3-3 base shape with explicit football roles. Roles are runtime interpretation and do not become a second career-data source of truth.

## Added
- `lib/models/player_role.dart`
- `PlayerRole` runtime enum covering goalkeeper, defenders, midfielders, wide players and striker archetypes.
- `Match2DPlayer.role` with a backwards-compatible default.
- Role assignment during Match2D player creation from player position + manager style.
- Role-aware starting positions and off-ball movement.
- Full-backs can overlap under high-press / wing-play identities.
- Ball-playing / cover defenders separate their depths.
- Anchor / playmaker / box-to-box midfield behaviour differs.
- Wide and inverted attackers alter lateral occupation.
- False nine drops toward midfield; target/pressing/poacher forwards alter depth and pressure.

## Formation contract
The current XI selection remains 1 GK + 4 DEF + 3 MID + 2 WING + 1 ST, therefore the canonical shape is a 4-3-3 base. This stage intentionally does not introduce a persistent club formation field; the role layer is runtime-derived from the existing authoritative club managerStyle.

## Integrity
Unchanged:
- official result ownership
- RNG/result reconciliation
- fixture reconciliation
- save transaction
- career/world simulation ownership

## Validation limitation
Flutter/Dart SDK is not installed in the environment, so `flutter analyze`, `flutter test`, device tests and builds cannot be truthfully marked as executed.

Static checks performed:
- verified the new role model is imported by Match2D
- verified all Match2D player creation paths pass manager style
- verified every PlayerRole enum value is handled by role movement logic
- verified the source archive can be repackaged successfully
