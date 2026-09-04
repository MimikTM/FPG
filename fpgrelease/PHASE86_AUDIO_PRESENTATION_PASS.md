# Phase 86 — Audio & Presentation

Status: **ASSET PASS / DEVICE QA REQUIRED**

## Installed presentation assets
- menu music
- career music
- match music
- UI click
- UI success/error
- countdown
- goal
- ball kick
- crowd

## Completed
- Central `FPGAudio` router.
- Separate music/SFX volume controls.
- Dual SFX players to reduce overlap cancellation.
- Audio settings persist locally.
- Match/career/menu tracks are addressable without gameplay changes.

## Device QA
- [ ] music starts on launch
- [ ] music volume reaches silence at 0%
- [ ] SFX volume reaches silence at 0%
- [ ] goal SFX does not stop crowd ambience unexpectedly
- [ ] rapid UI taps remain responsive
- [ ] leaving match stops/changes track correctly
- [ ] app background/foreground does not leave a stuck player

## Exit criterion
Audio enhances feedback without becoming repetitive, clipped or intrusive.
