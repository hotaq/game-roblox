-- GAME-25 verified lifecycle audit, 2026-10-27. Readable report; no gameplay side effects.
return [====[
GAME-25 completed: repeated-run and disconnect cleanup

Outcome
Reproduced four lifecycle defects, applied small targeted repairs, and verified them with
two real Studio clients, three warmups + twenty measured restart cycles, and a continuous
900.046-second soak. All 32 live acceptance checks passed; no captured Goblin script errors.
Six cleanup boundary checks and the existing 33 server + 9 visual axe checks also passed.
Source changes arrived through Git/Rojo; no production Script.Source writes were used.

Before / after
- Uncollected client gems after three ended runs: 10, 20, 30 before; zero after every
  post-fix cycle. Server already had zero. Retired IDs now return their client parts to
  the existing pool after queued death packets; new-run drops are preserved.
- Old Humanoids retained by the server's hit-cooldown table: 2, 3, 4 before; zero after
  every post-fix cleanup. Dead/unparented keys are pruned before the global card pause.
- Peer departure while the survivor chooses a card: one invalid fireball owner before,
  zero after. Ended/disconnected/replaced-character fireballs are pruned even while paused.
- Departed player's ring and slash-side cache: one orphan of each before, zero after.
  PlayerRemoving now destroys the ring and removes the player's cache entry.
The death-animation/model pool design, weapon stats, sword visuals and map were preserved.

Repeatability and provenance
Pre-fix measurement fixture: 7269a06. Repairs and full runtime sources: 83486ea.
Boundary runner: 7cb130c (after integration with the owner's concurrent asset work).
Before launch, all four relevant Studio runtime sources matched the repository exactly.
Main place: 96482005947199. Tests ran as background StudioTestService helpers, with
MainWindowHandle=0 in the process checks. All helpers closed and the main Studio returned
to Edit after completion.
The full test ran approximately 14:00-14:20 UTC on 2026-10-27.
Map1 stayed present at 5288 descendants throughout this fixed test-place snapshot.
This is not a whole-scene comparison against GAME-23: that task's two batches were
confounded by Map1 being introduced between measurements.

Twenty measured restart cycles (after three warmups)
Every cycle used the same 100-enemy/four-weapon workload, real death and the production
restart/lobby/card remotes. Samples were taken after the same five-second cleanup wait.
All twenty samples: server runs/gems/shots/axes/old-hit keys = 0; client live goblins,
gems/fireballs/axes/rings/damage labels and departed-owner references = 0.
Client pooled capacity was exactly stable across all twenty samples:
110 goblin models, 10 gems, 49 damage labels, 3 fireballs, 2 sword sweepers, 24 highlights.
Horde descendants: exactly 3280 in every sample. Sound templates: exactly 10.
Run UI descendants ranged 298-358 because random card artwork differs, without increasing
across cycles. The soak's UI count was exactly 298 throughout.
One fire event created one fireball; one hit pair created one label and one SFX play
after the repeated restarts. Connection objects were not directly enumerated.

Continuous soak
100 enemies, all four current weapons at level 1, fixed player position; one controlled
kill/drop/pickup per second, with enemy health reset to prevent uncontrolled extra deaths.
The existing step(), replication, client rendering, death animation, sounds and tweens ran
at real wall-clock cadence. Sampling did not manually clear client caches.
There were 15 minute-spaced samples. Server instances stayed exactly 83004, with one
current Humanoid hit-cooldown entry and zero leftover gems. Client gem pool stayed 10.
Damage-label capacity warmed from 91 at minute 1 to 94 at minute 2, then stayed 94 through
minute 15. Visible labels plus pooled labels were counted together.
After warmup, Horde descendants alternated 3416/3433 with the temporary 17-instance axe.
Server total memory ranged 1686.93-1692.88 MB; client total memory 1758.68-1780.39 MB.
These process/engine counters fluctuate and are not pure game-script allocations.

SceneAnalysisService cross-check (early / minute 6 / minute 14)
GoblinHordeClient VM bytes: 206384 / 209948 / 207250.
GoblinRunUI VM bytes:       89233 / 89157 / 89185.
GoblinSFX VM bytes:         14325 / 12453 / 12453.
GoblinHorde server VM:      296058 / 311227 / 331619.
The server fixture deliberately retains each report sample, so its growing diagnostic
report is included in that server-script heap. Do not label this production retention.
No unparented instances were attributed to GoblinHorde in any of the three queries.
HordeClient consistently held 4 Animation objects and 432 AnimationTracks for its pool.
Audio memory was exactly 4436880 bytes in all three client queries (including core/avatar
audio); GoblinSFX's loaded assets totaled 1593286 bytes. There were 10 sound templates.
Other stable engine/GoblinAI animation/path references were recorded without speculative
changes. In particular, the core Animate script's single old Humanoid did not accumulate.

Final cleanup
After the soak, death/lobby + five seconds left zero active runs, enemies, gems,
fireballs, axes, rings, damage labels, orphan owners and old hit-cooldown references.
The pools were 110 models / 10 gems / 94 labels / 3 fireballs / 2 sweepers / 24 highlights.
Final Horde descendants: 3415. All 900 controlled gem pickups produced 900 gem sounds.
No remaining reproduced retention defect in the audited paths.

How to rerun / evidence
- GAME25Protocol.lua: workload, cleanup interval, scope and interpretation.
- RunGAME25.lua: background launcher; {pilot=true} for the short diagnostic.
- TestGAME25.lua: exact-production-span ownership/retired-ID boundary regression.
- AnalyzeGAME25.lua: validates and summarizes the full raw acceptance.
- GAME25Pilot.lua, GAME25Acceptance.lua: complete raw pre/post JSON reports.
- GAME25SceneEvidence.lua: complete early/middle/late SceneAnalysis query results.
All named files are under roblox/benchmarks/.

Limits and next action
This bounded test covers the existing sword/fireball/ring/axe and horde lifecycle.
It does not qualify foreground/mobile FPS, arbitrary future weapons, or every possible
disconnect timing. UI stability is supported by object counts and observed event effects,
not a direct connection count. Reuse the fixture for new content; add its owner/lifetime
case, and repeat the full soak when shared run/projectile/cleanup logic changes.
No blocker remains for GAME-25. The shared source reservation is released after handoff.
]====]
