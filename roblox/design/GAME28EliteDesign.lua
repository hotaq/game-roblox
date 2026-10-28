-- Prototype specification; default OFF, Studio only. No shared-run redesign.
return [====[
GAME-28: Camp Breaker elite, 2026-10-28

Purpose: interrupt routine XP circling with a readable heavy attack and a
recovery opening. Reuse the v2 humanoid GoblinAI template and published clips;
no new model or animation asset. The ordinary horde remains data-only.

Config.EliteTrial.Enabled=false. A named GAME28Elite disposable test may enable
it; a published server cannot enable it through this option. For a manual
Studio trial, enable the flag through the repository/Rojo workflow, test, then
restore false. Never write production Source directly into Studio.

One encounter per uninterrupted set of runs. After the longest eligible run
has90 active seconds, snapshot Player+run identities currently in the arena.
Spawn one elite24 studs away inside the arena. HP300*(1+.5*(members-1)); speed10.
The regular horde's XP, population, health and damage curves remain unchanged.
No late membership or replacement run inherits reward rights. When all runs
end the attempt latch resets. No regular camp goblins are re-enabled.

Use existing HeavyAttack:1.1s windup, direction tracks only until0.35s, authored
hit window1.1..1.2333s, then an extra1s recovery after authored Recover1.5333s.
Ground rectangle marks the forward8x9-stud attack. Damage18 once per character
per swing. Sidestep after the early lock; do not just trade with a large HP bar.
Stunning hits interrupt for0.6s, then cannot re-stun until3s after the last stun.
Ring, rocks and totem's non-stunning hits do not interrupt. Existing humanoid
movement/pathfinding is retained. This is not a promise that every new mountain
ledge is navigable: manual review must check actual routes before activation.

The existing six weapons query an internal target index -1. It is never part
of the horde count, snapshot, incarnation packet, hit-number packet or XP-gem
stream. The actual server Humanoid replicates normally and GoblinVFX uses its
existing tag/animations. Incarnations keep per-weapon contact ledgers separate
across elites. Only current eligible roster runs can hurt it, and damage credit
is capped to actual remaining HP. There is no client damage/reward request.

GAME-11's newer per-player pause wins over older global-pause proposals:
choosers cannot attack, receive elite hits or be selected as targets. Peers
continue. The60-active-second optional window stops only when all remaining
eligible participants are choosing. Expiry removes the elite without ending
anyone's main run or awarding a reward. Arena change, no eligible original
members, out-of-arena elite or all players leaving cancels it. Death and pending
callbacks have bounded cleanup; one corpse lasts0.6s.

Reward: one ordinary upgrade offer per original member still connected, alive,
on the same run/character and in the arena when the server commits defeat.
Distance within the arena does not change entitlement. A chooser queues this
behind their current offer. Consume the encounter before updating recipients;
one receipt per run prevents duplicate grants. Last hitter gets one kill stat,
not exclusive ownership of the team's card. No persistent money, shared gem XP,
revive, late-join catchup or eight-minute victory rules are introduced here.
This bounded reward follows GAME-27's team fairness direction without treating
its unimplemented broader encounter proposal as production behavior.

Verification: real solo/two-client HeavyAttack dodge/hit, recovery, stun and
immunity, all six weapon paths, per-player pause, queued cards, reward dedup,
stale/replaced/dead/late membership, expiry/arena/disconnect cleanup, then a
scripted natural-AI fight with normal auto weapons. Four alternating12-second
performance phases use200 horde enemies and identical routes/seeds; discard
the first3s of each. Record step p50/p95, engine Physics/Heartbeat counters,
elite instance count and spawn wall time. Background counters are provisional,
not mobile FPS or isolated CPU attribution. No-elite phases have the feature
enabled but no actor, so the comparison measures the added encounter workload.

Keep/change/drop conclusion belongs in GAME28EliteReport after measurements.
Keep it disabled until the prototype's readability and gameplay value have
been reviewed; automated scripted success is not human fun evidence.
]====]
