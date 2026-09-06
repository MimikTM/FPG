# PHASE 6 — 62 SET-PIECE GAMEPLAY

Implemented a runtime set-piece layer for Match2D.

## Scope
- Corners now select an aerial target and defensive marker using attributes/roles.
- Fouls now classify the restart as a direct free kick, attacking free kick/cross, recycled restart, or penalty when the foul occurs in the attacking penalty area.
- Penalties use the taker's shooting/overall/stamina and goalkeeper context through the existing match shot resolver.
- Set-piece logic does not own the official result, reconciliation, RNG seed contract, or save transaction.
- Existing event/stat structures remain compatible; new `freeKick` and `penalty` event types are presentation events only.

## Validation
- Added `test/set_piece_engine_test.dart`.
- Flutter/Dart SDK availability remains an environment constraint; no Flutter analyzer/build/device run is claimed unless executed by the project environment.
