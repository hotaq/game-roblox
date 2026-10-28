-- Documentation only; not mapped by Rojo or required by gameplay.
return [====[
GAME-11 reproduction protocol (2026-10-28)

Use the normal game repository/Rojo workflow. Never overwrite production
Script.Source. Verify the mapped Edit sources match the intended revision.
Load RunGAME11Complete.lua as a function in Edit, then call one test at a time:
  runner({clients=2})
  runner({clients=1,mode="balance",seconds=120,baseline=true})
  runner({clients=1,mode="balance",seconds=120,candidate=true})
  runner({clients=1,mode="balance",seconds=120,candidate2=true})
  runner({clients=1,mode="balance",seconds=120}) -- production config

The runner uses StudioTestService:ExecuteMultiplayerTestAsync, disposable
helpers, and a ServerStorage.GAME11_<UUID> result folder. Status must be Complete,
callOK true, and result.ok true. Failed pilots are evidence, not passes.
Keep helper windows hidden and main Studio in Edit. Helpers end themselves.
The fixture only runs for the explicit GAME11Complete test name.

Acceptance uses two real clients and real RemoteEvents. Wait for each new offer
to reach the client before valid input; intentionally stale clicks bypass that
wait. Check independent four-weapon pause, protected/anchored chooser, ongoing
peer damage, no chooser XP/kill credit, active-clock compensation, reroll
deadline preservation, real 20-second expiry, fresh deadline for queued levels,
independent simultaneous choices, death/end/disconnect cleanup, and zero Goblin
errors. A disconnected InvokeClient may abort normally; still require actual
PlayerRemoving cleanup of the run and its shield within the bounded timeout.

Balance uses Random.new(11011), StressZone, an anchored scripted 12-stud circle
at angular speed .65 rad/s, and a 10000HP damage-measurement dummy. It calls the
real simulation and client card input, prioritizing evolve/sword/ring/weapon.
The default Health regeneration script is disabled, and all negative health
changes are summed (heals cannot erase previous damage). Card pauses and their
wall time remain in the report. It samples every ten seconds for 120 seconds.
Historical modes explicitly override their original contact damage too.
This is a controlled pacing/pressure comparison, not human survival, enjoyment,
full eight-minute progression, mobile FPS, or a statistically powered trial.
Wall scheduling and card/spawn RNG consumption cause repeat variation.

Run exact-source regressions in Edit without assigning Source:
  TestGAME12Server(configSource,serverSource)
  TestGAME11Death(clientSource)
  TestGAME24(serverSource,clientSource)
  TestGAME25(serverSource,clientSource)
Use current sources and compile every mapped Lua source. The mixed death test
covers both goblin and skeleton pools. Its counters are not GPU/FPS measures.

Soft materials: inspect all six actual client swatches before applying.
ApplyCampMaterials({mode="preview"}) lists eligible existing FlatGround parts.
ApplyCampMaterials({mode="apply",renderVerified=true}) changes Material and
MaterialVariant only, preserving every Color/CFrame/Size. It leaves grass
blades, dark/metal/neon accents, Lighting, pads and Map1 alone. Repeating apply
is stable. mode="revert" restores saved original material properties.
Include the Edit place material assignments in the owner's normal place Save;
Git contains the reproducible operator, not a serialized copy of the place.
]====]
