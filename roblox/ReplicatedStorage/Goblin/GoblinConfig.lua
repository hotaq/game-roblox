-- GoblinConfig (ModuleScript, ReplicatedStorage.Goblin)
-- Every gameplay value and asset ID for the goblin enemy lives here.
-- "rbxassetid://0" = REPLACE after uploading: Asset Manager > right-click the asset > Copy Asset ID.
local Config = {}

-- GAME-29 lab only: never enabled in published servers. Leave false until evaluated.
Config.ObjectiveTrial = { Enabled=false, Trigger=30, Window=35, Hold=8, Radius=8, Decay=1 }

Config.Tag = "Goblin" -- CollectionService tag on every goblin model

-- Uploaded 2026-10-25 from goblin/textures/vfx/*.png. Re-upload + replace if you edit the PNGs.
Config.Textures = {
	Slash = "rbxassetid://125436767772213", -- vfx_slash.png  (sword trail)
	SlashArc = "rbxassetid://139964682139060", -- ink slash, 4x4 flipbook, from the VFX Studio plugin library (owner's pick)
	SlashWave = "rbxassetid://13494950328", -- VFX Studio "CircularSmoke": the sword's Lv4+ shockwave ring
	SlashSmoke = "rbxassetid://13525831027", -- VFX Studio "CloudFx": the sword's Lv5 smoke puffs
	Spark = "rbxassetid://73368593132738", -- vfx_spark.png  (impact sparks, telegraph glint, stun stars)
	Burst = "rbxassetid://101702985444399", -- vfx_burst.png  (hit flash)
	Dust = "rbxassetid://102159467271043", -- vfx_dust.png   (footsteps, lunge, slam, body fall)
	Smoke = "rbxassetid://78889473112923", -- vfx_smoke.png  (death smoke)
	Ring = "rbxassetid://89996613812409", -- vfx_ring.png   (heavy-attack telegraph, slam shockwave)
	Pixel = "rbxassetid://119273301334400", -- vfx_pixel.png  (death dissolve cubes)
	-- Fire Ring (GAME-41), from the VFX Studio plugin library
	RingFlame = "rbxassetid://13504062786", -- "FlareFlipbook", white flame, 2x2 flipbook (tinted in code)
	RingSmoke = "rbxassetid://291880914", -- "Fire1", smoke puff
	RingCircle = "rbxassetid://691179887", -- magic circle, the Lv3+ ground glyph
	RingBurst = "rbxassetid://15811794808", -- "Fire Magic", burn sparks on the Lv4+ pulse
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
	-- Ground positions for the standing humanoid goblins. Empty since 2026-10-28: the owner wants the camp clear at game
	-- start. The old four were (-12, 0, -16), (12, 0, -16), (-6, 0, -28), (8, 0, -28) in the camp clearing (FlatGround).
	SpawnPoints = {},
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
	ModelScale = 0.7, -- horde goblin size (1 = the 6.4-stud model); applied to the HordeModel template on the client
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
	Order = { "sword", "fire", "ring", "axe", "rocks", "totem" },
	totem = {
		Name = "Lightning Totem", Icon = "T", Color = Color3.fromRGB(108, 190, 203),
		Levels = {
			{ Text = "Place a stone totem that zaps nearby goblins", Damage = 18, Cooldown = 7, Duration = 5, Range = 18, Targets = 1, Interval = 1, Knock = .2, Stun = false },
			{ Text = "Stronger lightning", Damage = 25 },
			{ Text = "Zap two goblins each pulse", Targets = 2 },
			{ Text = "Longer reach and lifetime", Range = 22, Duration = 6 },
			{ Text = "Three targets, faster pulses", Targets = 3, Interval = .8 },
		},
	},
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
	Order = { "might", "area", "haste", "magnet", "force", "duration", "projectile", "speed", "luck" },
	MaxLevel = 5,
	might = { Name = "Might", Icon = "^", Color = Color3.fromRGB(255, 210, 90), Per = 0.10, Text = "+%d%% damage for all weapons" },
	area = { Name = "Area", Icon = "[]", Color = Color3.fromRGB(111, 208, 160), Per = 0.10, Text = "+%d%% attack size" },
	haste = { Name = "Haste", Icon = ">>", Color = Color3.fromRGB(111, 176, 245), Per = 0.08, Text = "-%d%% weapon cooldown" },
	magnet = { Name = "Magnet", Icon = "U", Color = Color3.fromRGB(240, 120, 160), Per = 0.25, Text = "+%d%% gem pickup range" },
	force = { Name = "Force", Icon = "<>", Color = Color3.fromRGB(245, 140, 90), Per = 0.5, Text = "Hits knock goblins back (+%d%%)" },
	duration = { Name = "Duration", Icon = "D", Color = Color3.fromRGB(103, 193, 172), Per = .15, Text = "+%d%% fireball and totem lifetime" },
	projectile = { Name = "Projectile", Icon = "+", Color = Color3.fromRGB(229, 171, 87), Per = 1, Flat = true, Text = "+%d fireball and axe per volley" },
	speed = { Name = "Speed", Icon = ">", Color = Color3.fromRGB(131, 192, 221), Per = .08, Text = "+%d%% movement speed" },
	luck = { Name = "Luck", Icon = "?", Color = Color3.fromRGB(174, 151, 214), Per = .12, Text = "+%d%% rarity luck (better Rare/Epic odds)" },
}

-- One explicit evolution card: Lv5 weapon + this passive at any level. No extra slot.
-- Names and stat overrides are shared by combat, HUD and results. Sword specials remain GAME-34.
Config.Evolutions = {
	sword = { Passive="might", Name="Ruin Cleaver", Text="Stronger, wider slashes on both sides", Stats={Damage=28,Range=9,Arc=180,Cooldown=.7,Knock=1.3} },
	fire = { Passive="projectile", Name="Ember Volley", Text="Five fireballs pierce three goblins each", Stats={Damage=24,Count=5,Pierce=3,Cooldown=1.05} },
	ring = { Passive="area", Name="Inferno Halo", Text="A wider halo burns harder and faster", Stats={Damage=12,Radius=14,Interval=.35} },
	axe = { Passive="speed", Name="Gale Axe", Text="Two swift axes return from longer throws", Stats={Damage=42,Count=2,Radius=2.8,Range=38,Speed=60,ReturnSpeed=90,Cooldown=1.4} },
	rocks = { Passive="force", Name="Ancient Ward", Text="Six heavy stones orbit with stronger force", Stats={Damage=35,Count=6,Radius=1.7,Orbit=8,Speed=2.7,Interval=.45,Knock=.7} },
	totem = { Passive="duration", Name="Storm Shrine", Text="Long-lived shrine zaps four targets faster", Stats={Damage=34,Targets=4,Range=24,Duration=9,Interval=.65,Cooldown=6} },
}

function Config.passiveAmount(id, rarity)
	local def=Config.Passives[id]
	return def.Per * (if def.Flat then 1 else Config.Run.Rarity[rarity].Mult)
end

function Config.canEvolve(run, id)
	local def=Config.Evolutions[id]
	return def~=nil and run.weapons[id]==#Config.Weapons[id].Levels
		and (run.passives[def.Passive] or 0)>0 and not (run.evolved and run.evolved[id])
end

-- Icons for the run UI: one 768x512 sprite sheet, 128 px cells, drawn in the Figma file's "Icons" page and rendered
-- by scripts/21_icon_sheet.js (textures/ui/icons_v2.png). Evolved weapons use "evo_<weapon id>".
-- Re-upload and replace Image if the PNG changes; Cells come from the script's cells.txt.
Config.Icons = {
	Image = "rbxassetid://101038375378802", -- owner's Creator Dashboard upload (decal 114200795236040)
	Cell = 128,
	Cells = {
		sword = { 0, 0 },
		fire = { 128, 0 },
		ring = { 256, 0 },
		axe = { 384, 0 },
		rocks = { 512, 0 },
		totem = { 640, 0 },
		might = { 0, 128 },
		area = { 128, 128 },
		haste = { 256, 128 },
		magnet = { 384, 128 },
		force = { 512, 128 },
		duration = { 640, 128 },
		projectile = { 0, 256 },
		speed = { 128, 256 },
		luck = { 256, 256 },
		skull = { 384, 256 },
		gem = { 512, 256 },
		heart = { 640, 256 },
		evo_sword = { 0, 384 },
		evo_fire = { 128, 384 },
		evo_ring = { 256, 384 },
		evo_axe = { 384, 384 },
		evo_rocks = { 512, 384 },
		evo_totem = { 640, 384 },
	},
}

-- Stats of a weapon at a level: its Levels[1..level] merged.
function Config.weaponStats(id: string, level: number, evolved: boolean?)
	local s = {}
	for i = 1, math.min(level,#Config.Weapons[id].Levels) do
		for k, v in Config.Weapons[id].Levels[i] do
			s[k] = v
		end
	end
	if evolved or level>#Config.Weapons[id].Levels then
		for k,v in Config.Evolutions[id].Stats do s[k]=v end
	end
	return s
end

return Config
