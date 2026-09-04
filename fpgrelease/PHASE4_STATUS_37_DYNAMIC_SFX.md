# FPG — PHASE 4 / STEP 37 — DYNAMIC SFX

Status: COMPLETE

Implemented a presentation-side dynamic SFX state layer:
- contextual event selection
- event intensity
- audio ducking amount for layered mix control
- timed decay
- reset
- trigger helper

Prepared event vocabulary:
- kick
- pass
- tackle
- save
- net
- crowd
- whistle
- impact

Architecture preserved:
- SFX state is presentation-only
- Match2DEngine remains authoritative
- ready to connect to actual audio assets/mixer

Next:
38 Goal Celebrations
39 UI Reactions
