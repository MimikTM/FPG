# Phase 6 — Etap 80: FULL GAMEPLAY RESULT MIGRATION

Status: COMPLETED

Interactive, unplayed career fixtures opened in MatchScreen now run with
`gameplayResultAuthority: true`. Their final `MatchResult` is built from the
completed Match2DEngine state through `GameplayCareerIntegration` and is then
committed once by `GameEngine.commitGameplayMatchResult`.

The migration is intentionally scoped to the interactive career fixture.
Already-played fixtures remain presentation/replay-only and keep their stored
result. Bulk/day simulation for other fixtures remains unchanged.

## Authority chain

Gameplay → GameplayResultAuthority ledger → GameplayCareerIntegration →
MatchResult → fixture + league table + career statistics → save.

No second result simulation is performed at commit time.
