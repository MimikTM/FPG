# FPG 0.8.5v — Diamond Polish Pass 1

## Completed in this pass

- Save/load remains private-app storage based; no broad Android storage permission is required.
- Career creation now confirms the save before leaving the creator screen.
- Failed career creation save rolls back the active career object instead of presenting a false success state.
- Added persistent gameplay settings:
  - Easy / Medium / Hard / Simulation difficulty
  - Auto-save
  - Vibrations toggle
  - Decision confirmations toggle
- Mini-games now have a real per-stage timeout and cannot remain indefinitely in an active state.
- Dribbling is now player-controlled until the stage timer expires instead of auto-ending after a fixed animation.
- Simulation difficulty reacts to league level and player OVR.
- Starting OVR selector added: 40 / 45 / 50 / 55 / 60 / 65 / 70.
- Starting OVR affects potential: higher starting OVR gives less long-term potential.
- Settings now expose manual save and delete-save actions.
- Save deletion removes primary, backup and temporary save files.
- App version displayed as `0.8.5v`; the old `v26` label was removed from settings.

## Intentionally not claimed as finished yet

- Full Polish league database (Ekstraklasa + 1 Liga + 2 Liga + 3 Liga groups)
- Full training/minigame visual overhaul
- Full music/SFX system
- Interactive tutorial
- Final APK QA on a real Android device

Flutter/Dart SDK is not installed in the current execution environment, so the project was structurally inspected and modified but an actual `flutter analyze` / `flutter test` / APK build could not be executed here.
