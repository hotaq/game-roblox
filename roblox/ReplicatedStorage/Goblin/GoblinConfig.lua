-- GoblinConfig (ModuleScript, ReplicatedStorage.Goblin)
-- Every gameplay value and asset ID for the goblin enemy lives here.
-- "rbxassetid://0" = REPLACE after uploading: Asset Manager > right-click the asset > Copy Asset ID.
local Config = {}

Config.Tag = "Goblin" -- CollectionService tag on every goblin model

-- Uploaded 2026-10-25 from goblin/textures/vfx/*.png. Re-upload + replace if you edit the PNGs.
Config.Textures = {
	Slash = "rbxassetid://125436767772213", -- vfx_slash.png  (sword trail)
	SlashArc = "rbxassetid://139964682139060", -- ink slash, 4x4 flipbook, from the VFX Studio plugin library (owner's pick)
	Spark = "rbxassetid://73368593132738", -- vfx_spark.png  (impact sparks, telegraph glint, stun stars)
	Burst = "rbxassetid://101702985444399", -- vfx_burst.png  (hit flash)
	Dust = "rbxassetid://102159467271043", -- vfx_dust.png   (footsteps, lunge, slam, body fall)
	Smoke = "rbxassetid://78889473112923", -- vfx_smoke.png  (death smoke)
	Ring = "rbxassetid://89996613812409", -- vfx_ring.png   (heavy-attack telegraph, slam shockwave)
	Pixel = "rbxassetid://119273301334400", -- vfx_pixel.png  (death dissolve cubes)
}

-- Published from ServerStorage.GoblinAnims (09_gen_anims.py) via Save to Roblox, titled Goblin_<Name>.
Config.Animations = {
	Idle = "rbxassetid://134268202081136",
	CombatIdle = "rbxassetid://96257744798971",
	Alert = "rbxassetid://133280873945206",
	Walk = "rbxassetid://100143407160443",
	Run = "rbxassetid://114078325430368",
	TurnLeft = "rbxassetid://102022521631585",
	TurnRight = "rbxassetid://77122034430635",
	Attack1 = "rbxassetid://114959003198727",
	Attack2 = "rbxassetid://104352727812296",
	Attack3 = "rbxassetid://80697772055881",
	HeavyAttack = "rbxassetid://96272500993457",
	LungeAttack = "rbxassetid://101712054024928",
	HitFront = "rbxassetid://95895184395136",
	HitLeft = "rbxassetid://98827467337173",
	HitRight = "rbxassetid://84198849881626",
	Stun = "rbxassetid://138126044476311",
	Knockback = "rbxassetid://116951030818764",
	Death = "rbxassetid://92578798836618",
	Jump = "rbxassetid://129782374599464",
	Fall = "rbxassetid://95323874284201",
	Land = "rbxassetid://131102995523441",
}

Config.VFX = {
	UpdateDistance = 150, -- studs from the camera; farther goblins skip VFX work entirely
	MaxActive = 24, -- only the nearest this many get bone-tracked effects and animation events
	MaxEyeLights = 12, -- PointLights are the costly part: nearest this many only
	EyeLightDistance = 60, -- eye PointLights switch off beyond this (lights are the costly part)
	EyeLightBrightness = 1.2,
	EyeLightRange = 5,
	TrailLifetime = 0.16,
	DeathFadeTime = 1.2,
}

-- Server brain (ServerScriptService.GoblinAI). Distances in studs, times in seconds.
Config.AI = {
	SpawnPoints = { -- ground positions in the camp clearing (FlatGround)
		Vector3.new(-12, 0, -16),
		Vector3.new(12, 0, -16),
		Vector3.new(-6, 0, -28),
		Vector3.new(8, 0, -28),
	},
	RespawnTime = 10,
	MaxHealth = 100,
	WalkSpeed = 8, -- patrol
	RunSpeed = 16, -- chase
	ThinkInterval = 0.1,
	SleepRange = 150, -- no player this close: anchored, idle anim only, thinks once a second
	DetectRange = 40, -- needs line of sight
	LoseRange = 70,
	LoseTime = 4, -- give up after this long without line of sight
	PatrolRadius = 10, -- around the spawn point
	IdleTime = { 2, 5 },
	AttackRange = 6,
	AttackGap = { 0.2, 0.6 }, -- pause between swings so players get an opening
	HeavyChance = 0.3,
	HeavyCooldown = 8,
	LungeRange = { 10, 18 },
	LungeCooldown = 6,
	LungeSpeed = 37, -- ~10 studs between LungeStart and 0.6 s (animation_manifest displacement)
	LungeTime = 0.27,
	StunDamage = 35, -- damage taken within StunWindow that breaks its guard
	StunWindow = 2,
	StunTime = 2,
	KnockbackDamage = 30, -- one hit this big knocks the goblin back
	KnockbackSpeed = 23, -- ~8 studs over 0.35 s
	Attacks = { -- hitbox is a box in front of the goblin: Reach (forward) x Width; Knockback = push speed on the target
		Attack1 = { Damage = 10, Reach = 7, Width = 6, Knockback = 0 },
		Attack2 = { Damage = 10, Reach = 7, Width = 6, Knockback = 0 },
		Attack3 = { Damage = 14, Reach = 7, Width = 6, Knockback = 15 },
		HeavyAttack = { Damage = 28, Reach = 9, Width = 9, Knockback = 50, Heavy = true },
		LungeAttack = { Damage = 18, Reach = 8, Width = 6, Knockback = 35 },
	},
}

-- Horde goblins (ServerScriptService.GoblinHorde): data-only on the server, drawn by GoblinHordeClient.
Config.Horde = {
	Speed = 12,
	Spacing = 2.6, -- goblins push apart when closer than this
	Push = 6, -- how hard they push apart
	ContactRange = 3, -- this close to a player a goblin stops and swings (Attack1) ...
	AttackWindup = 0.55, -- ... and the hit lands this much later (Attack1's HitStart + the client's position lag) ...
	AttackReach = 4.2, -- ... only if the player is still this close: stepping away dodges it
	AttackCooldown = 1.2, -- per goblin, between swings
	ContactDamage = 6,
	IFrames = 0.5, -- per player, after a hit
	Slow = 0.5, -- a hit goblin walks at this fraction of its speed ...
	SlowTime = 0.7, -- ... for this long
	Stun = 0.2, -- and can't walk or swing this long first (a wind-up in progress is cancelled)
	Knockback = 14, -- only with the Force passive: push speed (studs/s) x the weapon's Knock x Force ...
	KnockbackDecay = 8, -- ... fading this fast (1/s): at Force 1.0, 14 / 8 = ~1.75 studs of slide
	MaxHealth = 30, -- at the start of a run; see Run.HealthPerMinute
	SpawnRing = { 45, 70 }, -- spawn this far from a player (off screen)
	SimRate = 30, -- movement steps per second
	SendRate = 10, -- snapshots per second to every client (clients smooth between them)
	ViewEnter = 192, -- player-centred interest, beyond normal camera/weapon reach
	ViewLeave = 224, -- keep existing neighbours a little farther to prevent boundary flicker
}

-- A run (GoblinHorde): starts when a player enters the arena, ends when they die.
Config.Run = {
	StartAlive = 25, -- horde size at 0:00 ...
	AlivePerMinute = 45, -- ... growing this much per minute of the longest running run
	MaxAlive = 700,
	HealthPerMinute = 0.4, -- goblin HP +40% per minute
	GemXP = 1,
	PickupRange = 5, -- studs; the Magnet passive multiplies it
	XPFirst = 5, -- XP for level 2; each next level needs XPGrowth times more (+1)
	XPGrowth = 1.22,
	Rerolls = 2, -- per run
	WeaponSlots = 4,
	PassiveSlots = 4,
	Heal = 30, -- the fallback card once everything is maxed
	Rarity = { -- card rarity: Mult scales a passive's bonus (weapon levels are fixed steps)
		{ Name = "COMMON", Weight = 70, Mult = 1, Color = Color3.fromRGB(201, 205, 211) },
		{ Name = "RARE", Weight = 25, Mult = 1.25, Color = Color3.fromRGB(111, 176, 245) },
		{ Name = "EPIC", Weight = 5, Mult = 1.5, Color = Color3.fromRGB(185, 138, 245) },
	},
}

-- Weapons fire on their own. Levels add up: level 3 = Levels[1] + [2] + [3]. Text is the card line for that level.
-- Knock = its share of the Force knockback; Stun = false for a weapon whose hits must not stun (they still slow).
Config.Weapons = {
	Order = { "sword", "fire", "ring", "axe", "rocks" },
	rocks = {
		Name = "Orbit Rocks", Icon = "RO", Color = Color3.fromRGB(153, 177, 132),
		Levels = {
			{ Text = "Two stones orbit and strike nearby goblins", Damage = 12, Count = 2, Orbit = 7, Radius = 1.25, Speed = 1.8, Interval = 0.55, Knock = 0.35, Stun = false },
			{ Text = "Heavier hits", Damage = 18 },
			{ Text = "+1 orbiting stone", Count = 3 },
			{ Text = "+1 stone, larger rocks", Count = 4, Radius = 1.55 },
			{ Text = "Ancient stones hit harder and orbit faster", Damage = 26, Speed = 2.2 },
		},
	},
	axe = {
		Name = "Boomerang Axe",
		Icon = "AX",
		Color = Color3.fromRGB(211, 174, 104),
		Levels = {
			{ Text = "Hits on the way out and back", Damage = 16, Cooldown = 2.4, Range = 24, Radius = 1.8, Speed = 38, ReturnSpeed = 52, Knock = 0.8 },
			{ Text = "+Damage", Damage = 24 },
			{ Text = "Wider axe, longer throw", Radius = 2.4, Range = 30 },
			{ Text = "Throws more often", Cooldown = 1.8 },
			{ Text = "+Damage, faster return", Damage = 34, ReturnSpeed = 64 },
		},
	},
	sword = {
		Name = "Wooden Sword",
		Icon = "/",
		Color = Color3.fromRGB(230, 224, 240),
		Levels = {
			{ Text = "Slashes in front of you", Damage = 12, Cooldown = 1.2, Range = 7, Arc = 110, Knock = 1 },
			{ Text = "+Damage", Damage = 17 },
			{ Text = "Wider slash", Arc = 160 },
			{ Text = "Also slashes behind you", Back = true },
			{ Text = "Faster slashes", Cooldown = 0.85 },
		},
	},
	fire = {
		Name = "Fireball",
		Icon = "*",
		Color = Color3.fromRGB(255, 154, 61),
		Levels = {
			{ Text = "Shoots the closest goblin by itself", Damage = 10, Cooldown = 1.3, Count = 1, Pierce = 0, Speed = 45, Range = 55, Knock = 0.7 },
			{ Text = "+1 fireball", Count = 2 },
			{ Text = "Goes through 1 goblin", Pierce = 1 },
			{ Text = "+1 fireball", Count = 3 },
			{ Text = "+Damage", Damage = 16 },
		},
	},
	ring = {
		Name = "Fire Ring",
		Icon = "O",
		Color = Color3.fromRGB(245, 184, 61),
		Levels = {
			-- no knockback and no stun: it ticks faster than a goblin's wind-up, so either would stop them attacking at all
			{ Text = "Burns goblins around you", Damage = 5, Interval = 0.6, Radius = 7, Knock = 0, Stun = false },
			{ Text = "Bigger ring", Radius = 9 },
			{ Text = "+Damage", Damage = 8 },
			{ Text = "Burns faster", Interval = 0.45 },
			{ Text = "Bigger ring", Radius = 11 },
		},
	},
}

-- Passives: each level adds Per x the card's rarity Mult. Text takes the percent.
Config.Passives = {
	Order = { "might", "area", "haste", "magnet", "force" },
	MaxLevel = 5,
	might = { Name = "Might", Icon = "^", Color = Color3.fromRGB(255, 210, 90), Per = 0.10, Text = "+%d%% damage for all weapons" },
	area = { Name = "Area", Icon = "[]", Color = Color3.fromRGB(111, 208, 160), Per = 0.10, Text = "+%d%% attack size" },
	haste = { Name = "Haste", Icon = ">>", Color = Color3.fromRGB(111, 176, 245), Per = 0.08, Text = "-%d%% weapon cooldown" },
	magnet = { Name = "Magnet", Icon = "U", Color = Color3.fromRGB(240, 120, 160), Per = 0.25, Text = "+%d%% gem pickup range" },
	force = { Name = "Force", Icon = "<>", Color = Color3.fromRGB(245, 140, 90), Per = 0.5, Text = "Hits knock goblins back (+%d%%)" },
}

-- Pixel icons for the run UI: one sprite sheet from scripts/13_icons.py (textures/ui/icons.png), 128 px cells.
-- Re-upload and replace Image if the PNG changes; Cells come from the script's printout.
Config.Icons = {
	Image = "rbxassetid://120198065824163",
	Cell = 128,
	Cells = {
		sword = { 0, 0 },
		fire = { 128, 0 },
		ring = { 256, 0 },
		skull = { 384, 0 },
		might = { 0, 128 },
		area = { 128, 128 },
		haste = { 256, 128 },
		magnet = { 384, 128 },
		force = { 0, 256 },
		gem = { 128, 256 },
		heart = { 256, 256 },
	},
}

-- Stats of a weapon at a level: its Levels[1..level] merged.
function Config.weaponStats(id: string, level: number)
	local s = {}
	for i = 1, level do
		for k, v in Config.Weapons[id].Levels[i] do
			s[k] = v
		end
	end
	return s
end

return Config
