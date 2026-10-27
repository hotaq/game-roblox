-- GAME12 remaining delivery contract (2026-10-28). Runtime config is authoritative.
return {
	acquisition="Totem and four new passives join ordinary random cards; existing four weapon/five passive slots are retained.",
	evolve="Weapon level5 plus paired passive>=1 enables explicit Evolve card, guaranteed one eligible evolution per offer. Same slot, passive retained, once per run. Server stores level5+flag; clients receive level6.",
	pairs={sword="might",fire="projectile",ring="area",axe="speed",rocks="force",totem="duration"},
	passives={
		duration="15% per level times rarity; increases fireball flight lifetime/range and stationary totem lifetime (20s hard cap).",
		projectile="One extra fireball/axe per level regardless of rarity, integer; max10 fireballs and8 axes per volley, max16 active axes.",
		speed="8% per level times rarity; based on run-entry WalkSpeed, max75% increase. End/departure restores only the value this run applied.",
		luck="12% per level times rarity, clamped at100%. Rarity weight i is baseWeight*(1+luck*(i-1)); common unchanged, higher tiers boosted. No guaranteed Epic.",
	},
	totem="Stone/moss/gold shrine with small cyan core. Levels 1/2/3/4/5 improve damage/target count/range+duration/target count+interval. Evolved Storm Shrine hits4. Max2 active per owner. No stun, snapshots at deployment, active simulation time only.",
	cleanup="Pause stops damage/lifetime. Cleanup precedes pause; invalid run/character/death/disconnect/arena exit/teleport>48 releases totems. End clears immediately. Cosmetic parts anchored/noncolliding/nonqueryable, <=20/model; transient lightning <=16 bolts x3 segments.",
	protocol="RunLevelUp(cards,rerolls,level,offerId), RunPick(index,offerId), RunReroll(offerId). New offers invalidate previous picks/rerolls, including queued level-ups.",
	validation="RunGAME12Complete with clients1 and2; exact Axe/Rocks/transport/cleanup regressions; TestGAME12Complete for rarity/offer/visual boundaries; actual Client screen capture for visual review. Never write runtime Source.",
	separate="GAME34 bespoke sword spin/wave/combo remains open. GAME15 moderated sprite atlas untouched. Approved sword models/VFX/music untouched. Existing balance/global pause policy unchanged.",
}
