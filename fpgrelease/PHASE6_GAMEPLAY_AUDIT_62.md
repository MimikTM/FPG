# Phase 6 Gameplay Audit — 62

Set pieces now participate in the same causal runtime chain as normal play:

restart context -> taker -> tactical role/attributes -> defensive setup -> execution outcome -> next ball state.

No second result authority was introduced.

Known limitation retained intentionally: the current Match2D still has legacy scheduled-goal materialization and final-score synchronization. Set-piece work does not remove that legacy authority; a later controlled result-authority migration is required.
