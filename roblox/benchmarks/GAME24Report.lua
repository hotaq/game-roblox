-- GAME-24 verified 2026-10-27. No gameplay side effects.
return [====[
Outcome: per-player horde interest is enabled (enter192 / leave224 studs).
Positions retain the original 1/8-stud precision. Compact slot masks reduce sparse snapshots;
dense fallback avoids mask overhead when everyone is visible. Incarnation metadata is sent
on entry/re-entry/reuse, with matching death/hit/swing events. Gems have independent visible
state and pickup positions, including hidden deaths and kill/pickup within one send interval.
Ready handshake repopulates existing state; disconnect removes the player's view records.

Verified: 16 matched phases with two real clients, 100/1000 enemies, clustered/separated,
broadcast/nearby, two repeats with reversed mode order; 5s warmup +15s samples per phase.
All122 matrix/lifecycle assertions passed, including20 visibility cycles, stale/current
events, slot reuse, distinct kill/XP credit, teleport, resync, actual departure and two fresh
connections, and empty final state. No captured Goblin script errors. Map1 held at5288
descendants in the frozen test scene. Real fresh simulated connections and receiver reset
are covered; this does not qualify production account/session persistence.

Measured mean per-client serialized buffer payload (includes enemy swing buffers):
100 separated: 3.67-3.68 ->2.059-2.062 KiB/s, 43.76-44.11% lower.
1000 separated: 36.27-36.29 ->19.66-19.73 KiB/s, 45.61-45.84% lower.
Clustered: 100 enemies uses4.27-6.38% MORE; 1000 uses2.20-2.73% MORE.
Clustered coordinates already use the dense fallback; event incarnation data adds overhead.
At1000, send p95 rises from0.135-0.173ms to0.629-0.743ms (+0.467-0.591ms).
Simulation p95 was6.63-7.94ms broadcast versus7.45-8.29ms nearby. This is a network/visibility
tradeoff, not a server CPU speedup. Two-client measurements do not establish scaling beyond
two players. Payload excludes RemoteEvent framing/compression, scalar args and weapon FX
tables. These results do not claim an equivalent total-network or device-FPS improvement.
Initial identity list is6bytes per visible slot (6000 for1000); steady state does not repeat it.

Regression: exact transport17, axe33 server+9 visual, cleanup6 checks passed. A real three-
restart GAME25 pilot with this transport left zero active enemies/gems/projectiles/rings
and zero orphan references after each cycle; modelPool110, gemPool10 and Horde3316 stable.
This targeted regression does not repeat GAME25's earlier15-minute soak.

Provenance: implementation9224587; swing accounting73779aa; diagnosticfe02a1b; reliable
test-state waits3b76f9d; chunked launcher36d64d2. Production sources exactly matched Studio
through Rojo before acceptance. No production Source writes, map edits or foreground actions.
Result: ServerStorage.GAME24_102b97c5-eb60-49f9-9a29-fcb0da0e2b92, Status=Complete.
RawReport has4 ordered JSON chunks totaling709425 characters; Report is16599 characters.
GAME24Acceptance.lua keeps the comparison/lifecycle data, omitting per-phase slot maps only.
AnalyzeGAME24.lua reproduces comparisons; GAME24Protocol.lua documents workload and limits.
Earlier pilot and cleanup regression evidence are retained separately. One earlier full run
lost its report to StringValue's200000-character limit and is not counted as acceptance;
the fixed storage span was separately checked with710118 characters before the successful run.

Next: GAME24 transport spans released. User requested GAME12 Orbit Rocks next; preserve the
owner's GAME33 sword FX and GAME35 held sword/animation work. Parent GAME12 remains broader.
]====]
