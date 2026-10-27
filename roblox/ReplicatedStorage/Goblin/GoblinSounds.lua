--!strict
-- Sound manifest for the horde game: every id is a free Creator Store audio asset that loaded in this experience
-- (checked 2026-10-27). Mix knobs: Volume, Pitch {min, max} (random per play), Cooldown (seconds a sound stays
-- silent after playing, so a big wave doesn't stack dozens of copies). Played by GoblinSFX.client.

export type Sound = { Id: string, Volume: number, Pitch: { number }?, Cooldown: number, Source: string }

local Sounds: { [string]: Sound } = {
	Slash = { Id = "135315310485417", Volume = 0.55, Pitch = { 0.95, 1.08 }, Cooldown = 0.05, Source = "sword-swing-whoosh-sound-effect-1 (Akin_TR), picked by the owner" },
	Fireball = { Id = "118217695193917", Volume = 0.4, Pitch = { 0.95, 1.1 }, Cooldown = 0.08, Source = "fireball-whoosh-5-179129 (mheedeng)" },
	Hit = { Id = "139520673393967", Volume = 0.35, Pitch = { 0.9, 1.15 }, Cooldown = 0.06, Source = "Hit sound (Juniur_TripleWapper)" },
	GoblinPop = { Id = "72264591133889", Volume = 0.45, Pitch = { 0.85, 1.2 }, Cooldown = 0.05, Source = "ui-pop-sound-316482 (BIushney)" },
	GoblinSwing = { Id = "134671877618939", Volume = 0.18, Pitch = { 0.6, 0.7 }, Cooldown = 0.6, Source = "Sword Swing Sound, pitched down" },
	Gem = { Id = "2575934454", Volume = 0.35, Cooldown = 0.04, Source = "Item Pickup (GnomeCode, CC0)" },
	Hurt = { Id = "126202409049252", Volume = 0.6, Pitch = { 0.95, 1.05 }, Cooldown = 0.3, Source = "enemy_damage (theProRacer8)" },
	LevelUp = { Id = "112485797063762", Volume = 0.6, Cooldown = 0.5, Source = "UI - Level Up (SodaBreadle)" },
	Reroll = { Id = "72264591133889", Volume = 0.5, Pitch = { 1.3, 1.3 }, Cooldown = 0.1, Source = "ui-pop-sound-316482, pitched up" },
	GameOver = { Id = "129285831966291", Volume = 0.6, Cooldown = 1, Source = "Arcade retro game over (agurkpaprika)" },
	-- The held sword (GAME-37): plant / pull / drag follow PlayerSword's SwordState; hit and wave follow the slash
	SwordPlant = { Id = "93066057522848", Volume = 0.6, Pitch = { 0.95, 1.05 }, Cooldown = 0.5, Source = "em0020_se_sword_stab_ground (kaaabbbooomm)" },
	SwordPull = { Id = "123481357235946", Volume = 0.5, Pitch = { 0.95, 1.05 }, Cooldown = 0.3, Source = "Classic Sword Unsheathe (Vic_Yza)" },
	SwordDrag = { Id = "136913781328946", Volume = 0.18, Cooldown = 0, Source = "metal_box_scrape_rough_loop1 (Mariolighyer), looped while running" },
	SwordHit = { Id = "135448977656112", Volume = 0.45, Pitch = { 0.9, 1.1 }, Cooldown = 0.06, Source = "p-skill-hit-iori (xzphp)" },
	SwordWave = { Id = "99957106744883", Volume = 0.35, Pitch = { 0.95, 1.05 }, Cooldown = 0.4, Source = "Flame Slam (Ground) (Timbulat99), Lv4+ shockwave" },
}

return Sounds
