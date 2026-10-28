-- Cheaper-death slice only. No gameplay side effects.
return [====[
GAME-11 cheaper horde deaths: verified 2026-10-28

Implementation a99924b; live tested with owner's model-scale fix 1c94fd1.
Only production change: GoblinHordeClient pool/death lifecycle.
The authored Death animation still supplies the fall. Playback is 2.5x, with
600ms retention and a 150ms fade. BodyFall (authored at 1.1s) occurs at 440ms,
before the fade starts. Stop run/swing/flinch so Action2 cannot mask the fall.
At most 64 corpses remain; overflow recycles the oldest. One Heartbeat queue
replaces a delayed callback for every death. Expiry never retains a callback
that could later hide a reused model. Recycle resets opacity and all tracks.
Server combat, rewards, XP, network identity/gem protocol and balance unchanged.

Controlled comparison (TestGAME11Death, baseline cb3841c)
Exact production receiver and lifecycle spans; mock tracks and deterministic
clock, one kill/respawn every interval for ten seconds. Not an FPS benchmark.
Kills/s     Peak corpses before -> after     Model capacity before -> after
20          40 -> 12                        41 -> 13
60          121 -> 36                       122 -> 37
120         241 -> 64                       242 -> 65
Float/frame boundary sampling can retain one extra baseline corpse.
Candidate 72 assertions passed; baseline 47. Includes twenty 1000-death bursts,
64-corpse cap, stable warmed capacity, stale/duplicate events, opacity reset,
slot reuse, legacy gem handling and final zero retained corpses.
Additional exact regressions: GAME24 transport 17/17; GAME25 cleanup 6/6.
Client compiles in Studio. No mobile/foreground GPU or whole-memory claim;
an already-expanded pool is reused, not shrunk by this patch.

Real model and visual review
Disposable hidden StudioTestService client, actual v2 mesh112179474618007,
scale0.7. Executed the exact acquire/recycle/death functions with real Animator
tracks: 20 death cycles completed, pool stayed at one, each root hidden,
death track stopped and opacity reset. Maximum observed recycle latency
633.85ms (600ms plus background scheduling). No fixture errors.
Front and back actual-client captures reviewed five authored poses at elapsed
0/.2/.44/.525/.59 seconds: readable fall then fade, retained green/brown club
silhouette. These were fixed poses for inspection, not performance readings.
RunGAME11DeathReview builds the disposable code from the current source;
execute it only in a hidden test client and end that session afterward.
The saved runner incorporates the owner's latest bounding-box HIP_Y formula
and front camera used during review; its earlier run used the equivalent
scaled template pivot before that concurrent owner fix landed.

Real production integration
Client and Config matched 1c94fd1 via normal Rojo synchronization; server was
unchanged and matched the repo. RunGAME24({quick=true}) launched two real
clients and replacement connections against frozen Map1 (5288 descendants).
26/26 assertions passed, zero captured Goblin errors. Includes visible/hidden
deaths, current/stale incarnations, both kill credits and distinct gems,
same-interval kill/pickup, twenty visibility cycles, teleport/resync, actual
disconnect, two fresh connections and final enemy/gem cleanup on both clients.
Full payload: GAME11DeathAcceptance.lua.
Studio result: ServerStorage.GAME24_8cb6040d-99d5-45f5-a0fc-7044ebdcb68d Complete.
This quick run omits the unrelated bandwidth matrix; no claim it was repeated.
All test helpers ended; main Studio stays Edit. All checked helper window
handles were zero. No production Source writes, foreground Play, map or
Lighting edits. Owner's showcase and new model-scale change preserved.

Remaining parent GAME-11 work
Icons already completed separately under GAME15. XP/horde/damage tuning,
per-player level-up pause and soft texture status still require their own
scoped verification; this slice does not close the entire parent task.
]====]
