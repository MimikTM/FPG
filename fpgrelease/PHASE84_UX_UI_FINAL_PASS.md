# Phase 84 — UX/UI Final Pass

Status: **STATIC PASS / DEVICE QA REQUIRED**

## Completed
- First-launch tutorial is already the default entry point for a new install.
- Manual tutorial remains available from Settings.
- Settings exposes difficulty, autosave, vibration, decision confirmation, theme and audio controls.
- Launch screen uses a short branded transition and routes to the correct first-run state.
- Release-facing Settings version label updated to `0.9.0 — Release Candidate`.
- Debug banner remains disabled for production presentation.

## Device QA checklist
- [ ] 360dp-width Android phone
- [ ] 412dp-width Android phone
- [ ] system font scale 1.3x
- [ ] light theme
- [ ] dark theme
- [ ] tutorial skip / resume
- [ ] back navigation from every top-level screen
- [ ] long text does not clip
- [ ] keyboard never obscures decision controls
- [ ] no unexpected overflow on match HUD

## Exit criterion
A complete new-career flow can be performed without dead ends, clipped primary actions or ambiguous destructive actions.
