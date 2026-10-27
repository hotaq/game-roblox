-- Real two-client gameplay evidence from the production axe with arena-exit guard.
-- Test-only setup: anchored/invulnerable players, automatic upgrade picks through RunPick,
-- runtime config adjustments attempted to accelerate acquisition, then Studio Horde count override=5.
-- This is functional/visual acceptance, not normal balance or device performance evidence.
return {
	date = "2026-10-27",
	map = "Map1",
	cardImage = "renders/game12_axe_live_card.jpg",
	motionImage = "renders/game12_axe_live_two_players.jpg",
	visualFinding = "Actual client screenshots: axe card icon and text readable; both spinning axes distinguishable beside both characters on studded terrain, pale steel against brown/green, restrained gold trail. Existing sword/ring effects remain visible. No offline render substitution.",
	observationsJSON = [==[{"observers":[{"loadout":"sword=5,axe=4,fire=3;magnet=2,force=3,haste=1,area=1","name":"Player2","evidence":{"PeakAxes":2,"NonCosmetic":0,"Axes":2,"Card":"[{\"id\":\"axe\",\"kind\":\"weapon\",\"rarity\":1,\"level\":4},{\"id\":\"force\",\"kind\":\"passive\",\"rarity\":2,\"level\":4},{\"id\":\"fire\",\"kind\":\"weapon\",\"rarity\":1,\"level\":4}]","Owners":"{\"Player2\":true,\"Player1\":true}"}},{"loadout":"sword=1,ring=4,axe=4,fire=2;might=2,area=2,force=2,magnet=2","name":"Player1","evidence":{"Cards":"[{\"id\":\"area\",\"kind\":\"passive\",\"rarity\":1,\"level\":2},{\"id\":\"sword\",\"kind\":\"weapon\",\"rarity\":1,\"level\":2},{\"id\":\"ring\",\"kind\":\"weapon\",\"rarity\":1,\"level\":5}]","Owners":"{\"Player2\":true,\"Player1\":true}","NonCosmetic":0,"LastPacketCount":1,"Axes":1,"PeakAxes":2}}],"afterDeath":{"ownersAfterPlayer1Death":{"Player2":true},"player2Loadout":"sword=5,axe=4,fire=3;magnet=2,force=3,haste=1,area=1","peakAxes":1},"deathSummary":{"kills":1880,"level":19,"time":462.44957280158997,"damage":[{"id":"sword","level":1,"amount":14889},{"id":"ring","level":4,"amount":71639},{"id":"axe","level":4,"amount":42657},{"id":"fire","level":2,"amount":3774}]},"afterDisconnect":{"player2Present":false,"remainingAxeModels":0}}]==],
	checks = {
		"Both real clients observed replicated axes for Player1 and Player2",
		"Both clients reached two simultaneous axe models; no colliding/touchable/queryable parts",
		"Player1 death removed only Player1's axes; Player2 continued with peak one",
		"Player1 results recorded axe damage in the real run summary",
		"Player2 disconnect removed final axe models from remaining client",
	},
	teardown = "StudioTestService.EndTest ended this dedicated test; temporary runtime character/config/camera changes discarded with test DataModels. Earlier unrelated test sessions left untouched.",
}
