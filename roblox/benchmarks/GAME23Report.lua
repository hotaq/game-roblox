-- Readable measurement report; returns text and has no gameplay side effects.
return [====[
GAME-23: repeatable horde baseline — 2026-10-27

Outcome
Completed two independent batches: 1/2/4 simulated clients and 100/500/1000 goblins.
36 phases passed integrity checks, with 18 matched primary phases and 84 client reports.
No captured Goblin script errors. All alive/visible counts matched their requested population.
This is a measurement deliverable; no optimization or gameplay retuning was applied.

Provenance and conditions
Gameplay baseline: c8712eaf3fd3c051fa627272f3756fab094a16a2 (GAME-11 rollback).
Instrumentation: f17b8fc, including be60722 and fixed-camera e2bc7ba.
Team tree assets from a3dcc8f were preserved; test helpers were synchronized through Rojo.
Local Studio window title matched the connected place: 96482005947199, PlaceVersion 9.
Studio 0.744.0.7441077; Windows 11 Pro 10.0.26200.
CPU i5-12400F, 6 cores/12 threads; RAM 31.86 GiB; RTX 3070, driver 32.0.16.1088.
Viewport 1688x800; Edit quality Automatic; StreamingEnabled true.
Server and simulated clients shared this host. Studio test helper windows were created by
StudioTestService in the background; the visibility/foreground check found no Studio window
in the foreground. These results do NOT qualify foreground/device/mobile FPS.
Scene check: FlatGround 4959 descendants, 4892 parts (4889 Plastic, 3 Neon), no variants;
Lighting Brightness 3.2, ClockTime 14.5, exposure 0.15. No scene writes were made by GAME-23.
Corrected batch collection ran approximately 10:17–10:38 UTC.

Concurrent-scene limitation discovered in final board review
GAME-31 imported Map1Kit templates into ServerStorage at 10:28:43 UTC, and GAME-32
assembled the new map at x=1000 at 10:38:14 UTC, during the overall collection window.
The tested horde source, StressZone route and alive/visible counts stayed verified, so
matched horde workload/serialization readings are useful provisional references.
The complete place was NOT frozen. Whole-scene memory/render comparisons across batches
are confounded and must not be used as controlled regression evidence. A frozen-scene
foreground pass is still needed for those budgets and for the new map itself.
The later sky change and Map1Spawn work were outside this collection's gameplay scope.
Two background measurements near 15 FPS do not prove that a new map adds zero cost.

Procedure
RunGAME23.lua launches one server with 1, then 2, then 4 clients.
Each session uses 100/500/1000 alive goblins twice, with 10s warm-up and >=20s collection
per phase. Players move on a radius-24 circle at 12 studs/s, evenly spaced; camera is fixed
at center+(70,65,70). Seed 23001. Test-only shields prevent player death; weapon tables,
initial gems/projectiles and pending upgrades are cleared to keep the workload fixed.
Normal Config, client effects, UI, map and Lighting remain unchanged.
This isolates horde movement/animation/snapshot costs; it excludes sustained combat,
death churn, upgrade decisions and full weapon/VFX load.

Comparison rule
The entire sequence was run twice in fresh sessions. Compare round 1 to round 1 across
batches as the primary baseline. Round 2 is a separate warm-pool/sparse-slot diagnostic.
Do not average percentiles: the tables show the range of each session's percentile.
The test's ascending kill-all reset combined with LIFO slot reuse creates sparse high
slots in round 2. Normal size reduction kills top slots, so this diagnostic is NOT
evidence that ordinary size reductions waste the same bandwidth.

Primary baseline (ranges across two independent batches)
Step and send values are milliseconds. Payload is raw HordeSnap KiB/s per client.

| Clients | Goblins | Step p50 | Step p95 | Send p95 | Snapshot payload |
|---|---|---|---|---|---|
| 1 | 100 | 0.20–0.25 | 0.39–0.46 | 0.048–0.052 | 3.60–3.61 |
| 1 | 500 | 1.55–1.71 | 2.43–2.70 | 0.111–0.130 | 17.80–17.93 |
| 1 | 1000 | 3.92–4.09 | 5.90–7.27 | 0.182–0.196 | 35.93–35.99 |
| 2 | 100 | 0.27–0.32 | 0.59–0.60 | 0.063–0.081 | 3.61–3.63 |
| 2 | 500 | 1.45–2.25 | 2.60–3.71 | 0.111–0.232 | 17.81–17.88 |
| 2 | 1000 | 3.32–4.38 | 4.90–5.88 | 0.123–0.189 | 35.79–35.88 |
| 4 | 100 | 0.21–0.24 | 0.41–0.51 | 0.064–0.100 | 3.56–3.59 |
| 4 | 500 | 1.16–1.23 | 1.57–1.72 | 0.103–0.113 | 17.79–17.88 |
| 4 | 1000 | 3.58–3.61 | 4.83–5.02 | 0.166–0.168 | 35.77–35.99 |

Three measured scaling costs and next actions
1. Server horde simulation: at 1000 enemies, step p95 is 4.83–7.27 ms, while snapshot
   send p95 stays below 0.233 ms across primary cases. Profile within step before changing
   algorithms; neighbor separation and target scans are source-level candidates, not
   separately measured causes. Four clients use different crowd spacing, so their lower
   timings do not mean extra players universally make the game cheaper.
2. Replicated snapshot volume: dense 1000-enemy snapshots are ~35.77–35.99 KiB/s to each
   client, or ~143–144 KiB/s of duplicated application payload across four clients.
   This is NOT wire throughput (compression/headers/other traffic excluded).
   GAME-24 should compare nearby-only selection with separated players, preserve events
   and identity, and report clustered cases where filtering has little benefit.
3. Client model/instance footprint: after the high-population phase, every measured client
   retains 1000 pooled models when only 100 or 500 are visible. In the first 1-client batch,
   engine instance count rose from 60155 to 85355 as models grew from 100 to 1000.
   Retention is bounded by this run's tested high-water mark; it is not proof of a leak.
   Use GAME-25 to examine ordinary restart/lobby/disconnect cleanup and memory stabilization
   before changing pool policy. Do not silently reintroduce the reverted GAME-11 redesign.

Recommended order
First profile simulation internals at 1000 enemies using this same fixture and a dense
combat case. Then use GAME-25 to establish whether retained resources are useful pooling
or unintended lifetime. Prioritize GAME-24 when supporting spread-out multiplayer/larger
arenas. Serialization micro-optimization is lower priority than measured simulation cost.
These are follow-up recommendations, not changes performed in GAME-23.

Budgets: proposed engineering targets, not achieved promises
- Horde step p95 <=4 ms: all primary 100/500 cases meet this; all 1000 cases exceed it.
- Horde send p95 <=1 ms: all primary cases meet this.
- Foreground frame p95 <=16.67 ms (60 fps) or <=33.33 ms (30 fps): NOT ASSESSED here.
- Network: keep current payload ranges as regression references; choose a product budget
  after target player count/range rules. No claim of a universal safe bandwidth cap.
- Memory: no device budget assigned until target-device and cleanup measurements exist.
- Compare repeated matched cases and observed variability before labeling a regression.

Background frame and memory readings (diagnostic only)
Frame intervals are ms, memory is Roblox Stats MB. Engine memory includes the whole
client/server scene and instrumentation, not just goblins; do not treat it as asset size.
Automatic quality, background throttling, CPU scheduling and concurrent simulated clients
can all affect rendering. GPU samples include zeros and are not used to assert a GPU limit.

| Clients | Goblins | Client frame p50 range | Client frame p95 range | Server memory p50 | Client memory p50 |
|---|---|---|---|---|---|
| 1 | 100 | 16.71–66.64 | 65.18–68.41 | 1571–1613 | 1647–1652 |
| 1 | 500 | 16.83–66.61 | 67.01–68.97 | 1561–1591 | 1675–1683 |
| 1 | 1000 | 18.10–66.67 | 68.61–69.94 | 1564–1592 | 1727–1746 |
| 2 | 100 | 16.99–66.68 | 67.65–69.56 | 1601–1604 | 1625–1653 |
| 2 | 500 | 66.53–66.69 | 69.04–70.18 | 1601–1609 | 1662–1691 |
| 2 | 1000 | 66.64–66.72 | 68.54–68.96 | 1602–1611 | 1719–1725 |
| 4 | 100 | 66.66–66.70 | 68.11–69.17 | 1620–1637 | 1634–1677 |
| 4 | 500 | 66.58–66.72 | 67.86–69.86 | 1624–1642 | 1679–1718 |
| 4 | 1000 | 66.60–66.93 | 69.85–74.31 | 1622–1640 | 1737–1775 |

Unavailable or excluded evidence
- Stats.DataReceiveKbps returned zero throughout despite observed received buffers. Treat
  this counter as unavailable in this test, NOT zero traffic. Raw buffer throughput is valid.
- No physical mobile/low-end device, foreground FPS, published multiplayer/network-latency,
  full combat, long-session leak test or profiler attribution was performed.
- An initial pilot cleared wOrder but not run.weapons; sword kills triggered upgrade pause
  and the population assertion stopped it. That pilot is INVALID and excluded from all data.
  The corrected fixture explicitly clears run.weapons; all accepted phases passed.

Artifacts and verification
GAME23Batch1.lua / GAME23Batch2.lua return raw JSON text.
GAME23Protocol.lua defines conditions/metric interpretation; RunGAME23.lua is the launcher.
ValidateGAME23.lua takes the two decoded batches and checks 36 phases/84 client reports,
quantile ordering, >=20s duration, >=550 server steps, exact alive/visible counts,
expected pool state, >=150 packets, no Goblin errors, and <10% client/server payload difference.
Both the Lua validator and independent local Python validation passed.
Source equality was checked after Rojo sync before collection. All changed Lua files compile.
Temporary result folders/marker are removed from Edit after raw evidence is saved.

References
https://create.roblox.com/docs/reference/engine/classes/StudioTestService
https://create.roblox.com/docs/reference/engine/classes/Stats

]====]
