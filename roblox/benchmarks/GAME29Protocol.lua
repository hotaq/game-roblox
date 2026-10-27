-- Reviewable protocol; no runtime side effects and not mapped by Rojo.
return [=[
GAME29 optional objective acceptance

Prerequisites: production Config.ObjectiveTrial.Enabled stays false. Compare repository
Config, GoblinHorde and GoblinStressHUD against the Edit place after the normal Rojo sync.
Do not assign Script.Source. Run TestGAME29 against repository server source for exact
boundary coverage, then evaluate RunGAME29(1) and RunGAME29(2) from Edit/MCP in sequence.
Each launcher creates disposable background StudioTestService multiplayer helpers and
writes JSON to ServerStorage.GAME29_<guid>.Report; Status must be Complete and result.ok true.
Do not stop unrelated Play contexts. The named fixture alone enables this prototype.
RunGAME29(clients,true) adds a60s marker review window before the functional scenarios.

HUD fallback inspection when the owner Rojo host has not pulled the latest patch:
launch the same background test with name GAME29VisualOnly (no production fixture),
evaluate BuildGAME29HUDProbe against repository server source in Edit, then execute the
returned command in that test's Server via MCP. It stops only that disposable helper's
ordinary horde Script and creates controlled runs for real players. Script.Source is never
assigned. Call ServerStorage.GAME29HUDProbe.Action:Invoke with progress/remove-first/success/
reset; inspect both actual Client PlayerGuis and capture the HUD. End only this test using
StudioTestService:EndTest. This checks UI replication/cleanup; its reward callback is mocked
and cannot replace the full ordinary-card acceptance above. A final sync remains necessary
before interactive testing of the latest integrated source in the owner's main place.

Functional checks: default-off absence, replicated marker, ignore without penalty,
progress decay/pause, normal reward-card delivery and selection, exactly-once completion,
restart eligibility, distant team reward, real departure, death at final tick, teardown.
Exact tests additionally cover existing queued cards, late joins, replaced runs/characters,
height/arena boundaries, stale callbacks and reference cleanup. No persistent economy.

Movement trials: Map1, record descendant count, ordinary level1 sword, no passives, normal
100HP, ForceFields removed, anchored roots moved by the fixture so routes are repeatable.
Suppress ordinary XP cards with next=1e9; use normal damage, sword attacks and objective
card reward. Clear old horde/gems; seed40 ordinary goblins at radius20 using golden-angle
positions and Random seed29, target40. Compare hold (radius0), inside-circle (radius6), and
wide-kite (radius16) at14studs/s. Optional peer circles at radius28 and16.8studs/s.
Initial placement contributes to distance. Trials stop at success, death, or12 active seconds;
wide-kite therefore need not reach the35s expiry (separate functional check covers expiry).
Record progress, status, reward count, HP/damage/death, travel, active time and wall time.

Interpretation limits: one seeded scenario per strategy/player count, not a balance sweep.
Enemy attack cooldowns use server wall time while objective/motion use fixed simulation dt;
helper scheduling can change damage, so these are directional observations, not causal
effect sizes or FPS benchmarks. Anchored scripted roots do not test navigation/collisions,
input feel, mobile visibility or human enjoyment. Existing goblins ignore map obstacles.
The far teammate route makes team eligibility visible but does not solve AFK carrying.
KEEP/CHANGE/DROP is a prototype recommendation; automated success never enables release.
]=]
