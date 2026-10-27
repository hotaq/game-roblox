-- Disabled Studio prototype, not an approved public-game rule. No runtime side effects.
return [=[
GAME-29: optional hold-zone trial

Trigger: only Studio with Config.ObjectiveTrial.Enabled=true or the named GAME29Objective
test. Default false and never enabled in published servers. After30 active-combat seconds
with at least one living run inside the arena, create one temporary radius8 marker24studs
from the arena Spawn toward Center (clamped inside its bounds). Existing map is unchanged.
One attempt per batch of concurrent runs; reset only after all runs have ended/disconnected.
This early trigger accelerates evaluation. GAME26's middle-run placement remains a hypothesis.

At spawn, snapshot eligible Player->run identities. This is a local objective roster,
not implementation/approval of GAME27's proposed encounter queue or locked team roster.
New runs/late joins after spawn cannot contribute or receive this attempt's reward.
At least one original living in-arena member inside the circle builds progress at1s/s;
additional members do not accelerate it. Outside the circle progress decays at1s/s.
Need8 accumulated seconds within35 active-combat seconds. The global card pause freezes
both progress and deadline, but departure/death/replaced-run cleanup still executes.
Leaving the circle is allowed. Ignoring or failing gives no penalty and does not end the run.
Changing arenas or losing all original members cancels the attempt. Vertical distance from
marker is limited so a character far above/below cannot count merely by matching X/Z.

Reward: one free ordinary upgrade offer to each original member still alive, connected,
in the same run and inside the arena at success. They need not be near the circle: one
player can hold while another kites, matching GAME27's proposed team reward eligibility.
No XP, character level, kill count, persistent currency or weapon is silently granted.
Reward enqueues into existing pending-card flow; an existing offer is preserved.
Commit phase/id and per-run receipt before notification, without yielding. Retries,
late callbacks, re-entry, death/restart and reconnect cannot replay the same event.
Original run references are released at terminal state; the latch remains until no runs.

Risk hypothesis: smaller safe movement area versus an upgrade for the team. Existing
enemies supply pressure; no extra waves or damage changes. A player may leave to dodge,
lose some progress and return. Full-team eligibility intentionally allows kiting support
but does not solve AFK carrying; no permanent reward is justified by this experiment.

Evaluation: exact lifecycle/reward boundaries plus real1/2-client card delivery and
completion. Compare scripted stationary hold, small movement inside the zone, and wide
kiting outside it under the same ordinary low-level weapon/seeded horde workload; record
health loss, time/progress/reward, death and distance moved. This is controlled behavioral
evidence, not a human-fun survey or a device/FPS benchmark.
KEEP only as a candidate if it creates an observable movement tradeoff and has no reward
duplication. CHANGE if stationary waiting dominates or roster/visibility is confusing.
DROP if it adds no useful choice after an alternative is tested. Leave disabled regardless
of automated success; user/owner playtesting is required before public release.
No elite, new map/artwork, persistent economy or global co-op XP implementation in scope.
]=]
