-- GAME-28 prototype evaluation,2026-10-28. KEEP the prototype; do not enable it for ordinary play yet.
return {
	conclusion="KEEP — bounded elite encounter and team reward work; retain defaultOFF until human gameplay/Map1 route review.",
	implementation="52d367a,b093f5c,e4165aa; integrated animation registry fix49fdf52. Latest tell initialization keeps hidden part near actor, not world origin.",
	integrated={
		solo={checks=36,ok=true,seconds=39.294107,health=100,rewards=1,result="GAME28_7526ed50-06c6-445b-87ba-be2cff71d74f"},
		team={checks=41,ok=true,seconds=26.068649,health=100,rewards=2,result="GAME28_b897bc85-c540-438e-a2a9-4a651386b7fa"},
		errors=0,
		coverage="Real HeavyAttack dodge/hit/recovery; stun duration/immunity and non-stun ring; all6weapons; chooser/peer independence; actual card delivery/picks; queued/once-only/team/stale/replaced/late/dead ownership; expiry/arena/actual disconnect cleanup.",
		fixture="Seeded scripted movement in StressZone, sword3/ring2; not human fun, survival difficulty or Map1 navigation evidence.",
	},
	fixes={
		"First live pilot crashed loading skeleton-only BoneThrow from shared Config.Animations. GoblinAI now skips entries outside its authored AnimData; realAnimator verifies all21goblin tracks and priorities/looping, skeleton clip remains in registry.",
		"Visual inspection found hidden EliteTell initially at world origin, stretching model bounds to1007x168x9 at distant spawn. Initialize at root.CFrame; exact clone bounds now8x8.04x9. No hit/timing change.",
	},
	performance={
		population=200,roundsPerSession=4,secondsPerRound=12,warmupDiscard=3,eliteInstances=217,
		solo={baselineStepP50={.4806,.4807},eliteStepP50={.4972,.5106},baselineStepP95={.7985,.831},eliteStepP95={.8653,.8223},
			baselinePhysicsP50={.000398,.000552},elitePhysicsP50={.023621,.047052},spawnMs={4.2269,4.5553}},
		team={baselineStepP50={.6075,.6914},eliteStepP50={.6352,.6618},baselineStepP95={1.158,1.258},eliteStepP95={1.1216,1.1984},
			baselinePhysicsP50={.014312,.017975},elitePhysicsP50={.031296,.134045},spawnMs={5.6956,4.9565}},
		interpretation="Small added median horde-step cost in solo; team step changes within observed variation. Extra Humanoid physics is visible and variable. No mobileFPS or production capacity conclusion.",
		limits="Hidden desktop helpers, same immutable scene within each paired session; unrelated owner helper processes were present and left untouched. Engine counters are provisional, not isolated CPU attribution. Do not compare memory with older Map1 scenes.",
	},
	visual={
		verified=true,scale=1.25,tellSize={8,.08,9},heldWindupSeconds=.6667,
		evidence="Exact production actor factory + HUD in disposable GAME28Inspect helper. Normal player camera with28stud zoom; real published HeavyAttack held only for still, then resumed:18damage and tell hidden during recovery.",
		note="Custom Scriptable-camera captures became blank; use normal camera. No owner main camera or map changes. GUI text clearly describes optional encounter, dodge and team upgrade; minimal prototype art, not a polished boss UI.",
	},
	safety={defaultEnabled=false,studioOnly=true,productionSourceWrites=false,ownerMapPreserved=true},
	followup={
		"Before enabling: human solo/co-op playtest whether spending~26–39scripted seconds for one card is worthwhile while normal horde pressure continues.",
		"Test real Map1 routes/trunks/pyramid ledges and spawn clearance; the owner is still editing that map. Existing Humanoid navigation is not a promise of full terrain traversal.",
		"If keeping for release, tune encounter cadence/HP/reward from play feedback, then improve ground cue/HUD to the final UI style. Do not infer authorization to enable from this KEEP decision.",
	},
}
