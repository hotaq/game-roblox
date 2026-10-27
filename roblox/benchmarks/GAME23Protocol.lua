-- GAME-23 reproducible baseline protocol (measurement, not production tuning).
-- 1. Pull main on the Rojo host; verify GoblinHorde and GoblinStressHUD match repo.
-- 2. Keep place/graphics/viewport/background status identical between repeats.
--    Record CPU/GPU/RAM/platform if obtainable; "unknown" is preferable to guessed hardware.
--    The machine running this Codex shell may differ from the Studio host.
-- 3. In Edit, read and execute RunGAME23.lua via the Studio plugin/MCP context.
--    It creates no scripts and never writes Script.Source. It starts disposable simulated sessions.
-- 4. Each 1/2/4-client session runs 100/500/1000 goblins, twice, in ascending order.
--    Each phase resets alive enemies and RNG, warms up 10s, then samples for >=20s.
--    Enemy spawning remains capped at the existing 20 per step.
--    Players are anchored and moved around a 24-stud circle at 12 studs/s, equally spaced.
--    They have a ForceField and no active weapons, so no death, XP, upgrade pause or DPS drift.
--    This is an isolated horde workload, NOT a full-combat, corpse-churn or real-device test.
--    Pools remain warm across phases; reset does not destroy reusable client pools.
--    IMPORTANT: ascending kill-all + LIFO slot reuse makes round 2 sparse at low populations.
--    Run the entire launcher twice in fresh sessions (archive/rename the first results folder).
--    Compare round 1 with round 1 across batches as the PRIMARY baseline; compare round 2
--    with round 2 separately as a warm-pool/sparse-slot diagnostic. Do not mix these states.
--    Normal population reduction kills top slots, so sparse-fixture bandwidth is not proof
--    of bandwidth waste in normal reductions. All reports must preserve this distinction.
--    Seed is fixed, but real heartbeat scheduling and equal-distance target ties may vary.
-- 5. Inspect ServerStorage.GAME23Results after Status=Complete.
--    There must be 3 successful session results, 6 phases each, and 1/2/4 client reports per phase.
--    Validate minAlive/maxAlive and each client's visible models == requested population.
--    Report script errors, timeouts and unavailable scenarios; never fill missing rows with estimates.
-- 6. Export raw JSON StringValues before deleting only the GAME23Results test artifact.
--    Restore Edit mode. Check no production configuration, map or Lighting values changed.
--
-- Metrics and interpretation:
-- stepMs: every actual horde step (os.clock around step), nearest-rank p50/p95/max.
-- sendMs: horde serialization + RemoteEvent calls; excludes transport latency.
-- heartbeatMs: actual server Heartbeat intervals; includes host scheduling and all game systems.
-- snapshotPayloadKiBps: actual HordeSnap buffer bytes / elapsed seconds / 1024.
--   Excludes protocol overhead, compression and other remote traffic; NOT total network throughput.
-- totalReceiveKbps: Roblox Stats.DataReceiveKbps, documented approximate kB/s, all incoming traffic.
-- frameMs: RenderStepped intervals; background throttling makes this unsuitable for device FPS.
-- renderCpuMs/renderGpuMs: Roblox Stats render seconds *1000; zero/unavailable samples need annotation.
-- memoryMb/instances: Roblox Stats aggregate counters, not proven per-DataModel allocations.
--   Simulated clients can share host resources. Do not sum these counters as independent processes.
-- Models/visible: horde folder counts, distinct from engine-wide instance totals.
-- The two repeats measure run variability; they do not establish a memory leak or device qualification.
--
-- Compare only same host, scene, graphics, fixture, population and client count.
-- Re-run if an unrelated Studio/art session changes the scene during collection.
-- Identify the three largest observed scaling costs, distinguish evidence from hypotheses,
-- and choose GAME-24 or GAME-25 based on those findings; do not change gameplay under GAME-23.
-- Documentation consulted:
-- https://create.roblox.com/docs/reference/engine/classes/StudioTestService
-- https://create.roblox.com/docs/reference/engine/classes/Stats
return {
    schema = 1,
    baselineGameplayCommit = "c8712eaf3fd3c051fa627272f3756fab094a16a2",
    instrumentCommit = "f17b8fc",
    independentBatches = 2,
    populations = {100,500,1000},
    clients = {1,2,4},
    repeats = 2,
    warmupSeconds = 10,
    sampleSeconds = 20,
    seed = 23001,
    cameraOffset = {70,65,70},
    proposedBudgets = {
        status = "provisional targets, not measured achievements; revise after baseline",
        hordeStepP95Ms = 4,
        hordeSendP95Ms = 1,
        foregroundFrameP95Ms60fps = 16.67,
        foregroundFrameP95Ms30fps = 33.33,
        -- Compare snapshot payload and engine network totals separately; no universal kB/s cap yet.
        network = "set after baseline and target-player-count decision",
        memory = "set after warm-up/cleanup trends and target-device decision",
    },
    hardware = "Windows 11 Pro 10.0.26200; i5-12400F 6C/12T; 31.86 GiB RAM; RTX 3070 driver 32.0.16.1088. Local Studio window title matches the connected place.",
    measuredResults = "GAME23Report.lua plus raw GAME23Batch1.lua and GAME23Batch2.lua; 36 validated phases and 84 client reports",
}
