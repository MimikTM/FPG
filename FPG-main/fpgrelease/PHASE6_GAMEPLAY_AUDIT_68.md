# Phase 6 Gameplay Audit — 68

### Authority separation
- GameplayResultAuthority owns only runtime score accounting.
- It cannot mutate fixtures, league tables, saves, or career state.

### Legacy path
- Existing target-goal path remains available by default.
- Scheduled goals and final score synchronization are preserved only in legacy mode.

### Emergent path
- `gameplayResultAuthority: true` removes target-goal authority from Match2DState.
- Goals can only increase through actual gameplay goal registration.
- No end-of-match goal injection occurs in this mode.

### Next validation
1. Run long deterministic matches in authority mode.
2. Compare score/xG/shot distributions with historical baseline.
3. Validate fixture reconciliation consumes the gameplay result exactly once.
4. Promote authority mode to default only after stability gates pass.
