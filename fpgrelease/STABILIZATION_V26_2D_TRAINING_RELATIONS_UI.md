# FPG V26 — Stabilization: match 2D, training, relations, season lifecycle, UI

## Fixed
- Daily career action is keyed to the in-game simulation date, so training unlocks automatically after advancing the day.
- Training UI explicitly reports whether today's action is available or already consumed.
- Season completion now has an actionable transition instead of a dead-end.
- Career projection synchronizes starter/substitute status into the world player used by the 2D match.
- 2D match now guarantees up to four player interaction moments when the controlled player is on the pitch.
- Goal events place the ball/scorer at the correct goal-side coordinates, preventing goals being shown from midfield.
- The unwanted “AI steruje wszystkimi 22 zawodnikami” message was removed.
- Relationship graph changes are kept in the persistent graph and natural drift is slowed to avoid an immediate 100 -> low-value snap.
- Core career screens move toward the supplied navy/cyan/purple match-center visual direction.

## Design rule
The player controls the simulation calendar. Device time is never used to advance the football day/night cycle.
