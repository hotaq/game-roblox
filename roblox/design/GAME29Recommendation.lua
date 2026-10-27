-- Recommendation based on 2026-10-27 scripted trials, not release approval.
return [=[
CHANGE; retain the prototype disabled for the next design experiment.

Correctness is promising: the 7e0c992 runtime passed 22 exact boundary checks and
14 solo / 17 two-client live checks, including real cards, death and departure.
No captured Goblin script errors. Both test places retained Map1's 5288 descendants.

But the movement hypothesis is not established. In this one seeded scenario,
stationary hold and radius6 movement both earned the same reward after8 active seconds.
The stationary holder finished with36.2 HP solo and42.1 HP in the two-player trial;
the moving holder finished with30.1 and12.1 HP. The distant support player stayed at100 HP
and earned the same one upgrade. A radius16 kite got no progress/reward by12.03 seconds.
Wide-kite ran longer, so its final HP cannot be compared directly as a damage penalty.
These results show that stationary waiting can succeed and team support can remain safe;
they do not establish that standing still is optimal across seeds, devices or real players.
The measured HP loss includes ordinary Humanoid regeneration, not cumulative damage.

The reward is optional and costly in health here, but this version does not yet justify
its added waiting or co-op free-rider incentive. Keep it out of the public game.

Next experiment proposal (not implemented): bank short segments of progress instead of
continuous8s, let the next segment appear at a second reachable point using the same marker,
and compare leaving to evade versus relocating. Avoid merely increasing hold duration or
enemy damage. Test several seeds/health states and ask humans whether the route choice is
readable and worthwhile. Establish the actual run/encounter roster before production team
rewards; this prototype's continuous-server batch latch is deliberately conservative and
can delay new players until everybody leaves. Resolve AFK carrying before durable rewards.
No new task or production gameplay approval is implied by this recommendation.
]=]
