-- Documentation only. Supersedes the remaining-work section of GAME11DeathReport.
return [====[
GAME-11 complete implementation and verification, 2026-10-28

Scope
Icons were completed under GAME-15. Cheaper horde death was implemented in
a99924b and visually/live verified in GAME11DeathReport and DeathAcceptance.
This completion adds independent per-player upgrade pauses, measured first-pass
XP/horde/contact tuning, and the six moderated soft camp materials. Owner
Skeleton, bright UI, MapLayout, mountain geometry and Map1 prop/texture changes
were pulled and preserved through 765e8a0. No production Source assignments.

Per-player pause
079c0c1 implements an owned root anchor and ForceField, RunPausedAt and a
20-second wall deadline per offer. A chooser stops its own weapons, projectile
lifetimes, XP pickup and kill credit. The chooser is absent from targeting and
hazard processing; teammates continue. Each active clock excludes its own
choice time. Reroll cannot extend the deadline. Timeout chooses card one using
the normal offer-ID validation; queued levels get fresh deadlines without a
protection gap. UI says SAFE and counts down. RunChoiceClosed is ID guarded.
Death, end and disconnect restore only this run's owned state.

Real acceptance: GAME11_d05d401e-2a9d-4c05-b028-6b3bef3b598a Complete, 27/27,
zero captured server/client Goblin errors. Two actual clients, real remotes,
real 20-second timeout and actual Kick/PlayerRemoving. Full payload is in
GAME11CompleteAcceptance.lua. Earlier failed fixture pilots are retained in
GAME11AcceptancePilots.lua and GAME11AcceptanceDisconnectPilot.lua. Fixes wait
for delivered card events, allow interrupted disconnect replies, and await the
deferred cleanup event. They do not bypass the cleanup assertions. Final named
fixture revision 222058c; gameplay tuning af15aba/fccdeba.

Measured first-pass tuning
                      Original       Candidate 1    Selected / repeat
XP first / growth     5 / 1.22       12 / 1.30      16 / 1.40
Start + per minute    25 + 45        20 + 35        20 + 35
HP growth / minute    40%            30%            30%
Contact / bone damage 6 / 8          6 / 8          5 / 8
First upgrade wall    14.9s          19.7s          27.4s / 19.8s
Level 4 wall          26.8s          47.4s          65.3s / 51.9s
Level at 120s         13             8              7 / 7
Alive at 120s         107            86             86 / 86
Cumulative damage     840            880            751 / 730

All rows use the same seeded scripted route, real combat and real card input;
the last repeat uses actual production Config, no tuning overrides. Every run
captured zero Goblin errors. The old exploratory pilot also reached level 4 at
32.2s and level 14 by 120s, but its net-health damage was invalid due to default
regeneration and is explicitly excluded from damage comparisons. The corrected
runs disable Health regeneration and sum health drops. Raw payloads are in
GAME11BalanceBaseline/Candidate/Selected/Production.lua, with the first pilot
retained separately. Timings vary because real wall scheduling changes spawn
and card RNG consumption. Level 4 after 60s is NOT guaranteed. The selected
curve roughly doubles time to level 4 and reduces early snowball without
making the first upgrade a long wait. Contact5 compensates for fewer early
upgrades; the owner's dodgeable skeleton bone8 is preserved.
These are 120-second background pacing/pressure tests with a 10000HP scripted
dummy, not claims of human survival, fun, late-run balance, mobile FPS, or a
confidence interval. Further human play can refine this initial tuning.

Soft camp textures
All six actual client swatches visibly rendered, then the existing camp was
reviewed with the textures applied. Assets: grass126261012928705,
dirt133288330441912,bark121757519712785,stone92748181928704,
bone96301841810258,cloth121513515493422. ApplyCampMaterials.lua uses the newer
GAME-20 preserve-colors decision instead of rebuilding FlatGround/Lighting.
It applied only Material/MaterialVariant on 2661 parts: grass1881,dirt119,
bark184,stone116,bone341,cloth20. All Colors/CFrames/Sizes preserved, total
FlatGround descendants unchanged at4959. No white-field regression in actual
client review. Repeat apply is stable; isolated six-kind apply/revert checks
restore original properties exactly and exclude grass blades/dark accents.
Main Studio still contains all2661 assignments. Git stores the reproducible
operator; the owner should include these existing Edit changes in the normal
place Save alongside GAME-43. This report does not claim a publish or Save.

Regression verification
All14 mapped Lua files compile. Exact current production spans pass:
48 weapon/card/speed checks,72 mixed goblin/skeleton death checks (including
twenty1000-death bursts),17 transport checks,6 cleanup checks. These complement
the27 real two-client pause checks. Existing death visual and network evidence
is retained in GAME11DeathReport/DeathAcceptance; no repeated full bandwidth
matrix or new FPS claim. Every checked helper window handle was zero; helpers
ended and main stayed Edit. GAME11CompleteProtocol.lua contains reproduction.

Handoff
Gameplay changes are in Config, GoblinHorde, GoblinHordeClient, GoblinRunUI;
the opt-in fixture participant is GoblinStressHUD. Materials use the standalone
ApplyCampMaterials operator. No remaining GAME-11 implementation or automated
acceptance blocker. Owner's separate GAME-43 exploration/place Save remains
under that task; future human balance feedback can produce a follow-up.
]====]
