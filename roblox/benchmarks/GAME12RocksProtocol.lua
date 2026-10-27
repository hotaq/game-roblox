-- Reproduce in Studio Edit/MCP after all five runtime sources match the repository through Rojo.
-- TestGAME12Rocks.lua(config,server,client): exact production simulation/card/visual spans.
-- RunGAME12Rocks.lua()({reviewSeconds=60}): two real background clients; actual card remotes,
-- HUD icons, peer visibility at levels1/3/5, contact/kill/XP ownership, pause, teleport,
-- restart/new character, real peer departure and final death. Optional motion review uses Map1.
-- This is functional/visual acceptance, not normal progression balance or an FPS benchmark.
-- Models have8..9 anchored Plastic parts/stone (at most36 per owner); no collision/touch/query.
-- Payload: at most4 stones/owner, described by one orbit row per10Hz snapshot. Ordinary weapon
-- FX replication still sends every owner's effects to every client, as existing axe/fire FX do.
-- Damage is authoritative. Sweeps subdivide curved motion; one cooldown per target incarnation
-- is shared by an owner's stones. Two players have separate cooldowns and damage credit.
-- Might scales damage, Area scales orbit/contact radius, Haste reduces target cooldown,
-- Force uses the existing knockback path. Rocks never stun; ordinary hit slowdown remains.
-- Orbit phase advances only during simulation, so the existing global card pause freezes it.
-- Cleanup/owner validation precedes that pause. Teleports over48studs reset the sweep; no
-- teleport trail damages enemies between origins. A live orbit follows ordinary owner motion.
-- Existing Hit SFX are reused; no new audio IDs, meshes, map edits, or shared icon-sheet changes.
-- Parent GAME12 also includes Lightning Totem, Duration/Projectile/Speed/Luck and Evolve.
return {weapon="rocks",levels=5,counts={2,2,3,4,4},damage={12,18,18,18,26},
	orbit=7,contactRadius={1.25,1.25,1.25,1.55,1.55},angularSpeed={1.8,1.8,1.8,1.8,2.2},
	targetCooldown=.55,knock=.35,stun=false,clients=2}
