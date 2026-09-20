# FPG V33 — Test Stability Fix

Fixes based on the V32 GitHub Actions test log.

1. Launch screen timer is stored and cancelled in dispose().
2. Global match goal assignment no longer indexes a stale immutable performance after repeated goal selection.
3. World roster validation distinguishes an unmaterialized roster index from an actual cross-club mismatch.
4. Squad-depth emergency players are followed by roster index synchronization.
5. WorldSave has a test-safe temporary-directory fallback when path_provider has no registered platform implementation.
6. MatchEngine regression expectation now reflects the documented result contract: playerPerformances contains both teams when both squads are supplied.

Quality gate remains unchanged: analyze, tests, APK and AAB must pass; no test is disabled to hide a failure.
