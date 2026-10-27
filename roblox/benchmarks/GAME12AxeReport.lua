-- Evidence for the Boomerang Axe slice; this does not close all of GAME-12.
return {
	date = "2026-10-27",
	implementationCommit = "95780d3",
	followup = "Reject new throws after arena exit; reproducible production-function and visual lifecycle checks.",
	status = "Implementation checked in isolation; live Rojo integration/playtest pending",
	method = "TestGAME12Axe.lua executed in Studio Edit with current repository Config, server and client source strings; no Script.Source writes.",
	resultsJSON = [==[{"ok":true,"count":33,"checks":["creates one axe toward nearest enemy","exactly one outgoing and one return hit, then catch","long frame uses swept hit","repeat sweep does not double hit same incarnation","reused slot can be hit as new enemy","return tracks owner movement","moving owner catches axe","lifetime expires with bounded cleanup","teleport invalidates projectile","arena exit invalidates projectile","outside owner cannot immediately create another axe","disconnected run no longer owns a projectile","replacement run cannot inherit old projectile","character replacement clears projectile","real endRun clears owned axes","three-projectile per-run limit","no target does not throw","zero-distance target uses finite direction","lethal hit credits one kill and one XP gem","level 1 and passive scaling","level 1 Force interaction","level 2 and passive scaling","level 2 Force interaction","level 3 and passive scaling","level 3 Force interaction","level 4 and passive scaling","level 4 Force interaction","level 5 and passive scaling","level 5 Force interaction","two runs keep damage ownership separate","ending one run preserves another player's axe","axe appears in ordinary new-weapon card pool","max axe is excluded from upgrade pool"],"mode":"isolated production functions, not live multiplayer","visual":{"ok":true,"count":9,"checks":["level 1 bounded cosmetic Plastic geometry","level 1 centered pivot and short non-emissive trail","level 3 bounded cosmetic Plastic geometry","level 3 centered pivot and short non-emissive trail","level 5 bounded cosmetic Plastic geometry","level 5 centered pivot and short non-emissive trail","first snapshot places visual correctly","next snapshot reuses model and updates targets","empty snapshot destroys visual"]}}]==],
	visualReview = {
		image = "renders/game12_axe_geometry_review.png",
		method = "Offline render of exact Part geometry/colors exported from makeAxeVisual at levels 1, 3 and 5; not a Roblox screenshot.",
		finding = "Blocky double-bit silhouette, matte wood/steel, restrained bronze/gold and jade match the natural LEGO/voxel direction. Existing map, Lighting and sword effects unchanged.",
		remaining = "Real camera scale, motion/trail, card icon and visual overlap must be reviewed after synchronization. Background Studio captures were black.",
	},
	blocker = "Team Create Edit session LocalPlayer AekKy0411; __Rojo_SessionLock held by hootoo1012. No local Rojo service/plugin connection found. No lock override or direct Source patch attempted.",
	nextAction = "Owner's active Rojo host pulls latest main; compare all five production script sources, then execute StudioTestService:ExecutePlayModeAsync({name='GAME12Axe'}) and inspect returned checks. Separate real two-client verification remains pending.",
	remainingParentScope = "Orbit Rocks, Lightning Totem, Duration/Projectile/Speed/Luck passives and Evolve.",
}
