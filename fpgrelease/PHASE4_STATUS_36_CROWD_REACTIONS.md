# FPG — PHASE 4 / STEP 36 — CROWD REACTIONS

Status: COMPLETE

Implemented a presentation-side crowd reaction controller with contextual states:
- CALM
- TENSION
- ROAR
- RELIEF
- GOAL_ROAR
- GROAN

Each reaction has:
- intensity
- short pulse
- timed decay
- reset support
- trigger helper

Designed to compose with:
- particles
- screen shake
- hit stop
- camera impact
- contextual camera

Architecture preserved:
- crowd reaction is presentation-only
- Match2DEngine remains authoritative

Next:
37 Dynamic SFX
38 Goal Celebrations
39 UI Reactions
