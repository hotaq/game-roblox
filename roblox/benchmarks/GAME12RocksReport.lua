-- Verified Orbit Rocks slice; parent GAME12 retains its remaining weapon/passive/Evolve scope.
return {
	date="2026-10-27",status="Orbit Rocks complete",implementation="5ed1ba4",visualAndFixtureFix="bf63ad9",
	checks={exactServer=28,exactVisual=7,realTwoClient=23,axeServerRegression=33,axeVisualRegression=9,networkRegression=17},
	resultFolder="ServerStorage.GAME12Rocks_a5577ac4-6c58-4041-b479-a1f6bfb2cb5b",
	result="Complete; all23 real-client assertions pass; zero captured Goblin script errors",
	behavior="Five levels,2/2/3/4/4 orbiting stones; authoritative curved contact sweeps with shared per-target incarnation cooldown. Normal card/HUD/results integration, Might/Area/Haste/Force compatibility, no stun. Pause, teleport, arena exit, end-run, replacement character and departure cleanup.",
	visual="Matte faceted stone, moss cap, small front/top gold runes. Actual Map1 client captures reviewed: stones and motion distinct from players, top runes visible against pale ruins, no glowing blanket/trails. UI name/text/icon readable.8..9 cosmetic parts per stone, at most36 per owner; no collision/touch/query.",
	motionImage="renders/game12_rocks_live.jpg",cardImage="renders/game12_rocks_card.jpg",
	visualContext="Two real clients with scripted camera and anchored protected players; levels5 and1 show6 live stones per observer. Stress panel and lingering fixture card overlay hidden only for motion capture. Normal UI closes the card through its Take button; acceptance invoked the production card remote directly. This is not ordinary progression/balance or device-FPS evidence.",
	verification="All five runtime files matched repository sources through Rojo before final launch.35 exact-span checks cover all levels/passives, curved/ordinary movement, cooldown/reuse, owner cleanup, card slot limits and visual reuse.23 live checks cover actual acquisition remote, card/HUD art, both observers/owners, damage/XP, pause/teleport, run end, respawn, real departure and final death. Existing axe42 and horde transport17 regressions pass.",
	limits="Prototype tuning; no new performance baseline, audio asset or SFX overhaul. Ordinary FX remain broadcast like existing weapons.34 earlier exact tests gained a moving-owner check, so final count35. Initial live pilot retained separately: missing fixture pausedAt caused two errors, fixed before successful repeat.",
	remainingParentScope="Lightning Totem; Duration, Projectile count, Move speed, Luck passives; Evolve. Boomerang Axe and Orbit Rocks slices are complete.",
	nextAction="Release rocks spans; select the next GAME12 slice on the board before editing. Do not mark the broader GAME12 done based on these two weapons alone.",
}
