# FPG — Gameplay Audit A–Z / Phase 6

## Executive assessment

The project is no longer only a menu-driven player simulator. It already has a substantial career/world simulation, transactional match result handling, a 2D pitch, player-controlled mini-games and a presentation stack.

However, it is **not yet a full football game** in the sense of a systemic, player-authored match simulation. The biggest gap is not UI; it is the connection between football decisions and the physical outcome of the match.

## Current strengths
- Strong world/career layer: transfers, loans, contracts, academy, relationships, media, board, managers and long-run integrity systems.
- Match transaction architecture is unusually disciplined: preview → interactive match → reconcile → single commit.
- Matchday presentation is mature enough to support a real game loop.
- 2D match already has ball ownership, movement, duels, transitions, situations, substitutions, cards, injuries, stoppage time and contextual player moments.
- Save/load and season transition have dedicated regression coverage.

## Main weaknesses
1. **Official result is still too authoritative for the live football.** The 2D match materialises scheduled goals from the pre-match result. This protects reconciliation, but it means tactics can visually influence play without fully owning the outcome.
2. **AI is still role/heuristic based rather than decision based.** There is no persistent tactical state machine for press, rest defence, possession circulation, transition and chance creation.
3. **Defensive line and transition phases are under-modeled.** A true game needs coordinated line height, compactness, cover/shuffle, counter-press and retreat behaviour.
4. **Player decisions are not contextual enough.** Passing, carrying, shooting and risk should depend on attributes, pressure, body orientation, space, score, stamina, role and team style.
5. **Formations are implicit.** Positions exist, but a real football game needs formation/role instructions and in-match shape changes.
6. **Set pieces are not yet a systemic gameplay layer.** Corners, free kicks, throw-ins and penalties should have authored tactical states.
7. **Player identity is only partly expressed on the pitch.** Pace, passing, dribbling, defending, physical and shooting need stronger causal influence on actions.
8. **Device verification remains the release blocker.** Static review cannot prove 60 FPS feel, collision quality, input latency, camera behaviour or save/force-close behaviour on Android.

## Priority roadmap

### 58 — Team Playstyle AI — DONE in this package
Connect club manager identity to tempo, width, forward risk, pressing and defensive depth. Weight generated attacking situations by style.

### 59 — Defensive Line & Transitions — NEXT
Create a shared transition state: `inPossession`, `loss`, `counterPress`, `retreat`, `settledDefence`, `recovery`. Add line height, team compactness, cover and runner tracking.

### 60 — Contextual Player Decisions — NEXT
Replace generic action choice with a scored decision model: pass / carry / dribble / cross / shoot / recycle / clear. Score each option from player attributes + pressure + space + style + game context.

### 61 — Formation & Role Instructions
Make 4-3-3, 4-2-3-1, 4-4-2 etc. real tactical shapes rather than only starting coordinates. Add role instructions and substitution shape changes.

### 62 — Set-Piece Gameplay
Corners, free kicks, penalties and throw-ins become explicit states with tactical routines and player choices.

### 63 — Match Consequence Layer
Goals, assists, cards, injuries, fatigue, morale and player match ratings should emerge from actions and feed the existing career/world systems through one commit path.

### 64 — Human Input & Control Feel
Improve player movement, anticipation, first touch, turning, sprint bursts and defensive control. The user should feel that controlling the player changes football, not just a mini-game result.

### 65 — Football Simulation Validation
Build headless scenario tests: possession team vs low block, high press vs direct, counter vs high line, late chase, fatigue collapse, 10v11, etc. Compare expected tactical signatures over hundreds of seeds.

## Definition of “real game”
The project should not be called a full football game until a user can reliably create a different match through football decisions: change tempo, exploit a wing, beat a press, defend a lead, counter into space, make a tactical substitution and see those decisions alter chances and the final result — while the existing career/save integrity remains intact.

The right next investment is therefore **gameplay causality**, not another menu/presentation screen.
