--!strict
-- MapLayout (ModuleScript, ReplicatedStorage.Goblin): Map 1 "Jungle Temple Valley" (GAME-43) as pure functions of a
-- position. Map1Builder builds the parts from it, GoblinHorde reads hazards from it, and GoblinHordeClient stands
-- goblins, gems and projectiles on heightAt, so the horde walks up the same terraces and stairs the player jumps up.
-- Local coordinates: (0, 0) = the map centre, north = -Z, 600 x 600 studs. The ground is 6-stud tiles and every tile
-- has one kind and one height, so heightAt is exact (it samples the tile's centre).
--
--   centre      stone plaza, the Maya pyramid (5 tiers to 51, temple on top at 75, stairs up every face)
--   ring        a river (2 studs deep: wading slows) around the plaza, a bridge on each side
--   NW          the big mountain: ridged rocky summits up to ~64 studs, climbed by jumping ledge to ledge
--   NE          a mesa (4 wandering tiers of 6 studs) with a waterfall into a deep cenote
--   E           a lumpy hill; SE stepping-stone pillars up to 20 studs; W raised ruin platforms
--   SW          the skeleton graveyard; S the spawn clearing and the path north to the plaza
--   edges       a jagged rock ridge and jungle, so the valley reads as closed
--   hazards     thorns hurt, mud and water slow (players and goblins)
-- Rock heights come from deterministic value noise (pure math, so server, client and builder agree) in whole 2-stud
-- bricks, so the mountains read as stacked bricks with ledges instead of smooth cones.
local Layout = {}

local TILE, HALF = 6, 300
local STEP = 2
Layout.TILE, Layout.HALF = TILE, HALF

local PLAZA = 60
local PYRAMID = { x = 0, z = 0, half = 66, base = -6, top = 75.6, cell = 2 } -- Map1Kit.Prop_Pyramid (Meshy temple
-- ruin), ~134 wide, its bottom sunk to y -6 (the owner's placement). Its highest surface every 2 studs (rows = x,
-- -65..65; two hex digits per cell = z, -65..65), baked from the mesh with
-- `scripts/26_plasticify_glb.py heights <generate.glb> 133.5726 2 -6 hex`: tiers at 5 / 17 / 28 / 39 / 51, the temple
-- on top at 75, stairs up every face. 2 studs, not a 6-stud tile: its tiers are only ~11 wide, so per tile the horde
-- stood inside the next tier up. groundAt (the horde) reads it directly; tiles (kinds, the builder) sample their centre.
local PYRAMID_FINE = {
	"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
	"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
	"000000000000000000000000000000000000000000000000000000010100000000000000000101000000000000000000000000000000000000000000000000000000",
	"000000000000000000000000000000000000000000000000000000040401010101010101010404000000000000000000000000000000000000000000000000000000",
	"000000000000000000000000000000000000000000000000000000060603030303030303030606000000000000000000000000000000000000000000000000000000",
	"000000000000000000000000000000000000000000000000000000090906060606060606060809000000000000000000000000000000000000000000000000000000",
	"0000000000000000000000000000000000000000000000000000000b0b08080808080808080b0b000000000000000000000000000000000000000000000000000000",
	"0000000000000000000000000000000000000000000000000000000e0e0a0a0a0a0a0a0a0a0d0e000000000000000000000000000000000000000000000000000000",
	"00000000000000000304050505050505050505050506050505050510100d0d0d0d0d0d0d0d1010050505050505050505050505050505050505050000000000000000",
	"000000000000000004050505050505050505050505050505050506131311111111111111111313050505050505050505050505050505050505050000000000000000",
	"000000000000000005050505050505050505050505050505050506151513131313131313131515050505050505050505050505050505050505050000000000000000",
	"000000000000000005050505080805050505050505050505050a06181715151515151415161817050505050505050505050505050808070605050000000000000000",
	"0000000000000000050505050f101111111111101112110e0e0e0e1a1917171717171616161a1a0e0e0e0e0e1111111111111111100f080606050000000000000000",
	"000000000000000005050505111111111111111011110e0e0e0e0e1c1c1a1a1a1a1a1a1a1a1c1c0e0e0e0e0e0e1111111111111111100e0606050000000000000000",
	"000000000000000005050506111111111111111111160e0e130e0e1f1f1c1c1c1c1c1c1c1c201f0e0e0e0e0e0e1111111111111111110f0505050000000000000000",
	"000000000000000005050507111111131b1c1c1c1c1c1c1c1c1c1c22221f1f1f1f1f1f1e1e21221c1c1c1c1c1c1c1c1c1c1b131111110f0505050000000000000000",
	"0000000000000000050505081111111c1c1c1c1c1c1c1c1c1c1c1c2424212121212121212123241c1c1c1c1c1c1c1c1c1c1c1b1111110e0505050000000000000000",
	"0000000000000000050505081111111c1c1c1c1c1c1c1c1c1c1c1c2727232323232323232326271c1c1c1c1c1d1c1c1c1c1c1c111111080505050000000000000000",
	"0000000000000000050505081111111c1c1c1c1c1c1c1c1c1c1c242929252525252525252528291c1c1c1c1c1c1c1c1c1c1c1c111110080505050000000000000000",
	"0000000000000000050505101010101c1c1c1c22252727272727272c2c28282828282828282b2b24242424272725221c1c1c1c101010080505070400000000000000",
	"0000000000000004060505081010101c1c1c1c26272727272727272e2e2a2a2a2a2a2a2a2a2e2e25252527272727251c1c1c1c101010100505050000000000000000",
	"0000000000000000050507081210101c1c1c1c272727272727272731312c2c2c2c2c2c2c2c3131252d2727272727271c1c1c1c101010090505050000000000000000",
	"0000000000000000050505081010101c1c1c1c272727272727302733332e2e2e2e2e2e2e2e333332272727272727271c1c1c1c101010090505050000000000000000",
	"0000000000000000050505091010101c1c1c1c272727293333333333333333333333333333333433333333272727271c1c1c1c101010090505050000000000000000",
	"0000000000000000050505091010101c1c1c1c272727293333333334333333333333333333333333333333272727271c1c1c1c101010090505050000000000000000",
	"0000000000000005050505091010101c1c1c1c272727293333333334333333333333333333333333333333272727271c1c1c1c101010090505050000000000000000",
	"0000000000000000050505091110101c1c1c1c272727293333333336334949494a49494a4a4a4a4a333333272727271c1c1c1c101011090505050000000000000000",
	"0000020407090b0e101315181a1e20222427292c2f3233333333393c484a4a4949494a4b4b4b4b4a33333333312f2c29272422201d1b181613110e0b090704010000",
	"0000020507090b0e101416181a1d202223272a2c2f32333333343a3c494a4a4949494b4a4b4b4b4a33333333312f2c292725221f1d1b181613110d0b090704010000",
	"0000000105060a0c0f111315181a1c1f212325282a2c31333333373d4a4a4a4949494a4a4a4b4b4a333333302c2c292523211f1c1a171513110f0a0a060501000000",
	"000000010506080c0f111315181a1c1f212325282a2c313333333c414a4a4949494a4a4a4a4b4b4a333333302c2a282523211f1c1a171512110f0b0a060501000000",
	"000000030506080b0e111315181a1c1f212325282a2c313333333f444a4a4a4a4a4a4a4a4a4b4b4a333333312c2c282523211f1c1a171513110f0b09060501000000",
	"000000030506080a0e111316181a1c1f212325282a2c3133333342434a4a4a4a4a4a4a4a4a4b4b4a333333312e2a282523211f1b1a171513110f0b0a060501000000",
	"000000010506080a0e111316181a1c1f212325282a2c313333334243494a4a4a4a4a4a4a4a4b4b4a333333312c2a28252321201c1a171513110f0b0a060301000000",
	"000000010506080a0e111316181a1c1f212325282a2c31333333424448494a4a4a4a4a4a4a4b4b4a333333312c2a282523211f1c1a171513110f0c08070301000000",
	"000000010507080a0d111316181a1c1f212325282a2c303333333c424449494a4a4a4a4a4a4b4b4a333333312c2a282823211f1c1a171513110f0c08070301000000",
	"000000010507080a0e111316181a1c1f212325282a2d3033333333333c4849494a4a4a4a4a4b4b4a333333312c2a292523211f1c1a171513110f0c08060301010000",
	"0000020407090b0d101315181b1d1f2224272a2c2f32333333333a3c3d4249494a4a4a4a4a4b4b4a33353333312f2c292724221f1d1a171513100e0c090604020000",
	"0000020407090c0e101315181b1d1f222427292c2f3233333433393c3c414849494a4b4b4b4b4b4a33333333312f2c292724221f1d19181513100e0c0a0604020000",
	"0000000000000000050505111110181c1c1c1c272727273433333636363f4247484a4a4a4a4a4a46333333272727271c1c1c1c101011110505050000000000000000",
	"00000000000000000505050b1010101c1c1c1c272727273333333333333333333333333333333333333333272727271c1c1c1c101110090505050000000000000000",
	"0000000000000000050505091010101c1c1c1c272727273333333333333333333333333333343333333333272727271c1c1c1c111010090505050000000000000000",
	"0000000000000000050505091010101c1c1c1c2727272d3333333333333333333333333333333333333333272727271c1c1c1c111010090505050000000000000000",
	"0000000000000000050505091010101c1c1c1c272727272a2a2a2a3333313131313131313133342a2a2a2a27272727261c1c1b111010090505050000000000000000",
	"0000000000000000050505091010111c1c1c1c272727272727272731312e2e2e2e2e2e2e2e313127272b27272727271c1c1c1c111410090505050000000000000000",
	"0000000000000000060505091010111c1c1c1c27272727282727272f2f2a2a2a2a2a2a2a2a2f2f27272727272727271c1c1c1c111110090506050000000000000000",
	"0000000000000000050505081011111c1c1c1c27272727272727262c2c28282828282828282c2c27272727272726251c1c1c1c111110050505050000000000000000",
	"0000000000000000050505081111111c1c1c1c1c1c1c251c1c1c1c2929252525252525252529291c1c1c1c1c1c1c1c1c1c1c1c111111080505050000000000000000",
	"0000000000000000050505081111111c1c1c1c1c1c1c1c1c1c1c1c2727232323232323232327271c1c1c1c1c1c1c1c1c1c1c1b111111080505050000000000000000",
	"0000000000000000050505081111111c1c1c1c1c1c1c1c1c1c1c1c2424212121212121212124251c1c1c1c1c1c1c1c1c1c1c1b111111080505050000000000000000",
	"000000000000000005050508111111131c1c1c1c1c1c1c1c1c1c1c22221f1f1f1f1f1f1f1f21221c1c1c1c1c1c1c1c1c1c1b13111111080505050000000000000000",
	"0000000000000000050505081111111111111111161111110a0a0a20201c1c1c1c1c1b1c1c201f101011111111111111111111111111080505050000000000000000",
	"000000000000000005050508111111111111111111110a0a0a0f0f1c1c1a1a1a1a1a1a1a1a1c1c101010111111111111111111111111080505050000000000000000",
	"00000000000000000505050810111111110e101011090e0e0e0e0f1a1a1818181818181818191a101010101111111111111111111110080505050000000000000000",
	"000000000000000005050505080f101111110f0f09090909090909181816151616161515161718090909090909101011111111110f08080505050000000000000000",
	"000000000000000004050505050505050505050505050505050b05151513131313131313131515050505050505050505050505050505050505050000000000000000",
	"000000000000000003030505050505050505050605050505050505131311111111111111111313050505050505050505050505050505050505050000000000000000",
	"00000000000000000003050505050505050505050505050505050510110f0f0f0f0f0f0f0f1010050505050505050505050505050505050505050000000000000000",
	"0000000000000000000000000000000000000000000000000000000e0e0a0a0a0a0a0a0a0a0d0e000000000000000000000000000000000000000000000000000000",
	"0000000000000000000000000000000000000000000000000002000c0b08080808080808080c0c000000000000000000000000000000000000000000000000000000",
	"000000000000000000000000000000000000000000000000000000090806060607070606060909000000000000000000000000000000000000000000000000000000",
	"000000000000000000000000000000000000000000000000000000070603030303030303030607000000000000000000000000000000000000000000000000000000",
	"000000000000000000000000000000000000000000000000000000040401010101010101010404000000000000000000000000000000000000000000000000000000",
	"000000000000000000000000000000000000000000000000000000010101010100000000000102000000000000000000000000000000000000000000000000000000",
	"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
	"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
}
for i, row in PYRAMID_FINE do -- decode once into numbers
	local cells = table.create(#row // 2)
	for k = 1, #row, 2 do
		cells[(k + 1) // 2] = tonumber(row:sub(k, k + 1), 16) :: number
	end
	(PYRAMID_FINE :: any)[i] = cells
end
local RIVER = { half = 100, radius = 32, width = 10, depth = -2 }
local BRIDGE = 9 -- half-width of the four bridges
local CENOTE = { x = 125, z = -110, rx = 22, rz = 18, depth = -4 }
local MOUNTAINS = { -- rocky massifs; noise only shrinks a footprint inside its ellipse, never grows it
	{ x = -185, z = -185, rx = 100, rz = 90, peak = 76, shape = "peaks", seed = 1 }, -- NW mountain
	{ x = 190, z = -180, rx = 72, rz = 62, peak = 24, shape = "mesa", seed = 2 }, -- NE mesa
	{ x = 235, z = 70, rx = 50, rz = 70, peak = 20, shape = "hill", seed = 3 }, -- E hill
	{ x = 118, z = -138, rx = 18, rz = 11, peak = 20, shape = "mesa", seed = 4 }, -- the falls: tiers down into the cenote
}
local RIDGE = { band = 56, low = 18, high = 60 } -- the valley wall: rises over the last 56 studs to 18..60 tall
local PILLARS = { -- SE stepping stones, each a 12 x 12 block: jump from one to the next
	{ x = 150, z = 200, h = 4 }, { x = 170, z = 186, h = 8 }, { x = 190, z = 200, h = 12 },
	{ x = 206, z = 182, h = 16 }, { x = 224, z = 198, h = 20 },
}
local PLATFORMS = { -- W ruin platforms (x, z = centre; hx, hz = half-size)
	{ x = -205, z = 10, hx = 18, hz = 12, h = 5 }, { x = -205, z = 40, hx = 12, hz = 9, h = 10 },
	{ x = -180, z = -20, hx = 9, hz = 9, h = 5 },
}
local GRAVEYARD = { x = -180, z = 175, rx = 72, rz = 56 }
local SPAWN = { x = 0, z = 238, rx = 46, rz = 32 }
local THORNS = { -- hazard patches (ellipses)
	{ x = -110, z = 95, rx = 16, rz = 12 }, { x = 95, z = 150, rx = 14, rz = 18 }, { x = -60, z = -150, rx = 18, rz = 12 },
	{ x = -140, z = 128, rx = 12, rz = 10 }, { x = 150, z = -40, rx = 12, rz = 16 },
}
local MUD = { { x = 60, z = 195, rx = 26, rz = 16 }, { x = -215, z = -50, rx = 18, rz = 18 }, { x = 40, z = -165, rx = 20, rz = 14 } }
local JUNGLE = 66 -- trees grow within this far of the border (and on the mountains)

Layout.SPAWN, Layout.PYRAMID, Layout.CENOTE, Layout.GRAVEYARD, Layout.PILLARS = SPAWN, PYRAMID, CENOTE, GRAVEYARD, PILLARS
Layout.PLATFORMS, Layout.MOUNTAINS, Layout.RIVER, Layout.BRIDGE = PLATFORMS, MOUNTAINS, RIVER, BRIDGE
Layout.FALLS = MOUNTAINS[4]

local function ellipse(x: number, z: number, e, grow: number?): number -- < 1 inside
	local g = grow or 0
	return ((x - e.x) / (e.rx + g)) ^ 2 + ((z - e.z) / (e.rz + g)) ^ 2
end
local function roundedSquare(x: number, z: number, h: number, r: number): number -- signed distance, < 0 inside
	local qx, qz = math.abs(x) - (h - r), math.abs(z) - (h - r)
	return Vector2.new(math.max(qx, 0), math.max(qz, 0)).Magnitude + math.min(math.max(qx, qz), 0) - r
end
local function inAny(x: number, z: number, list): boolean
	for _, e in list do
		if ellipse(x, z, e) < 1 then
			return true
		end
	end
	return false
end

local function pyramidHeight(x: number, z: number): number?
	local row = (PYRAMID_FINE :: any)[math.floor((x - PYRAMID.x + PYRAMID.half) / PYRAMID.cell) + 1]
	local h = row and row[math.floor((z - PYRAMID.z + PYRAMID.half) / PYRAMID.cell) + 1]
	return if h and h > 0 then h else nil
end

local function rand(ix: number, iz: number, seed: number): number -- 0..1 per lattice point
	local n = (ix * 1619 + iz * 31337 + seed * 6971) % 4294967296
	for _ = 1, 2 do
		n = bit32.bxor(n, bit32.rshift(n, 15))
		n = (n * 104729 + 12345) % 4294967296 -- stays under 2^53, so every machine gets the same bits
	end
	return n / 4294967296
end
local function noise(x: number, z: number, cell: number, seed: number): number -- smooth value noise, 0..1
	local gx, gz = x / cell, z / cell
	local ix, iz = math.floor(gx), math.floor(gz)
	local fx, fz = gx - ix, gz - iz
	fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
	local a, b = rand(ix, iz, seed), rand(ix + 1, iz, seed)
	local c, d = rand(ix, iz + 1, seed), rand(ix + 1, iz + 1, seed)
	return a + (b - a) * fx + (c - a) * fz + (a - b - c + d) * fx * fz
end
local function fbm(x: number, z: number, cell: number, seed: number): number -- 3 octaves, 0..1
	return (4 * noise(x, z, cell, seed) + 2 * noise(x, z, cell / 2, seed + 1) + noise(x, z, cell / 4, seed + 2)) / 7
end

local function massifHeight(x: number, z: number, m): number
	local d = math.sqrt(ellipse(x, z, m)) / (0.72 + 0.28 * fbm(x, z, 48, m.seed)) -- a wobbly rim
	if d >= 1 then
		return 0
	end
	local t = 1 - d -- 0 at the rim, 1 at the centre
	if m.shape == "mesa" then -- flat tiers with wandering edges, a few loose bricks on top
		local tier = math.clamp(math.floor(t * 4.5 + 1.2 * (fbm(x, z, 20, m.seed + 5) - 0.5)) + 1, 1, 4)
		return m.peak * tier / 4 + STEP * math.floor(noise(x, z, 9, m.seed + 6) * 1.6)
	elseif m.shape == "hill" then
		return m.peak * (1 - d * d) * (0.7 + 0.5 * fbm(x, z, 26, m.seed + 5))
	end
	local crest = 1 - math.abs(2 * noise(x, z, 36, m.seed + 3) - 1) -- sharp ridgelines between summits
	return m.peak * t ^ 1.05 * (0.6 + 0.4 * crest) + 8 * t * (fbm(x, z, 14, m.seed + 5) - 0.5)
end

-- The massifs and the valley ridge, in whole bricks (0 = flat ground).
local function rockHeight(x: number, z: number): number
	local h = 0
	for _, m in MOUNTAINS do
		h = math.max(h, massifHeight(x, z, m))
	end
	local edge = HALF - math.max(math.abs(x), math.abs(z))
	if edge < RIDGE.band then
		local s = 1 - edge / RIDGE.band
		local crest = 1 - math.abs(2 * noise(x, z, 30, 8) - 1)
		h = math.max(h, (RIDGE.low + (RIDGE.high - RIDGE.low) * fbm(x, z, 70, 9)) * s ^ 1.3 * (0.6 + 0.4 * crest))
	end
	return STEP * math.floor(h / STEP)
end

-- The SE stepping-stone pillars and the W ruin platforms (0 elsewhere).
local function ruinHeight(x: number, z: number): number
	local h = 0
	for _, p in PILLARS do
		if math.abs(x - p.x) <= 6 and math.abs(z - p.z) <= 6 then
			h = math.max(h, p.h)
		end
	end
	for _, p in PLATFORMS do
		if math.abs(x - p.x) <= p.hx and math.abs(z - p.z) <= p.hz then
			h = math.max(h, p.h)
		end
	end
	return h
end

-- The kind of ground at a tile centre. Plaza / Pyramid / Stairs / Water / Bridge / Shore / Cenote / Thorns / Mud /
-- Graveyard / Spawn / Path / Ruin / Mountain / Jungle / Grass.
local function kindAt(x: number, z: number): string
	if pyramidHeight(x, z) then
		return "Pyramid"
	end
	if math.abs(x) <= PLAZA and math.abs(z) <= PLAZA then
		return "Plaza"
	end
	local r = roundedSquare(x, z, RIVER.half, RIVER.radius)
	if math.abs(r) <= RIVER.width then
		return if math.abs(x) <= BRIDGE or math.abs(z) <= BRIDGE then "Bridge" else "Water"
	end
	if math.abs(r) <= RIVER.width + 4 then
		return "Shore"
	end
	if ellipse(x, z, CENOTE) < 1 then
		return "Cenote"
	end
	if inAny(x, z, THORNS) then
		return "Thorns"
	end
	if inAny(x, z, MUD) then
		return "Mud"
	end
	if ruinHeight(x, z) > 0 then
		return "Ruin"
	end
	if rockHeight(x, z) > 0 then
		return "Mountain"
	end
	if ellipse(x, z, GRAVEYARD) < 1 then
		return "Graveyard"
	end
	if ellipse(x, z, SPAWN) < 1 then
		return "Spawn"
	end
	-- a dirt path loop outside the river and spokes out to the spawn and the side zones
	local loop = roundedSquare(x, z, 160, 50)
	local spoke = (math.abs(x) <= 7 and math.abs(z) > RIVER.half and math.abs(z) < 230)
		or (math.abs(z) <= 7 and math.abs(x) > RIVER.half and math.abs(x) < 200)
	if math.abs(loop) <= 7 or spoke then
		return "Path"
	end
	if HALF - math.max(math.abs(x), math.abs(z)) < JUNGLE then
		return "Jungle"
	end
	return "Grass"
end

local function heightOf(kind: string, cx: number, cz: number): number
	if kind == "Pyramid" then
		return pyramidHeight(cx, cz) :: number
	elseif kind == "Water" then
		return RIVER.depth
	elseif kind == "Cenote" then
		return CENOTE.depth
	elseif kind == "Bridge" then
		return 1
	elseif kind == "Ruin" then
		return ruinHeight(cx, cz)
	elseif kind == "Mountain" then
		return rockHeight(cx, cz)
	end
	return 0
end

-- Per-tile cache: the noise is too slow to run per goblin per frame, and a tile never changes.
local cacheKind: { [number]: string }, cacheH: { [number]: number } = {}, {}

-- Local (x, z) -> kind and ground height (studs; the top of the ground at that tile).
function Layout.at(x: number, z: number): (string, number)
	if math.abs(x) >= HALF or math.abs(z) >= HALF then
		return "Outside", 0
	end
	local ix, iz = math.floor((x + HALF) / TILE), math.floor((z + HALF) / TILE)
	local key = ix * 128 + iz
	local kind = cacheKind[key]
	if not kind then
		local cx, cz = (ix + 0.5) * TILE - HALF, (iz + 0.5) * TILE - HALF
		kind = kindAt(cx, cz)
		cacheKind[key], cacheH[key] = kind, heightOf(kind, cx, cz)
	end
	return kind :: string, cacheH[key]
end

-- What standing here does to a player (and slows a goblin): {damage, every} or {slow}.
local HAZARDS = {
	Thorns = { damage = 4, every = 0.5 },
	Mud = { slow = 0.6 },
	Water = { slow = 0.7 },
	Cenote = { slow = 0.55 },
}
Layout.HAZARDS = HAZARDS

-- World-space helpers for the horde scripts: zero / no hazard unless Map1 is the arena in use.
local origin: Vector3? = nil
local function local_(x: number, z: number): (number?, number?)
	if workspace:GetAttribute("Arena") ~= "Map1" then
		return nil, nil
	end
	if not origin then
		local map = workspace:FindFirstChild("Map1")
		origin = map and map:GetAttribute("Center") :: Vector3?
		if not origin then
			return nil, nil
		end
	end
	local o = origin :: Vector3
	return x - o.X, z - o.Z
end
function Layout.groundAt(x: number, z: number): number
	local lx, lz = local_(x, z)
	if not lx then
		return 0
	end
	if math.abs(lx - PYRAMID.x) < PYRAMID.half and math.abs((lz :: number) - PYRAMID.z) < PYRAMID.half then
		return pyramidHeight(lx, lz :: number) or 0 -- its own 2-stud surface (plaza or lawn around it is 0)
	end
	local _, h = Layout.at(lx, lz :: number)
	return h
end
function Layout.hazardAt(x: number, z: number)
	local lx, lz = local_(x, z)
	if not lx then
		return nil
	end
	local kind = Layout.at(lx, lz :: number)
	return HAZARDS[kind]
end

return Layout
