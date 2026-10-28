--!strict
-- MapLayout (ModuleScript, ReplicatedStorage.Goblin): Map 1 "Jungle Temple Valley" (GAME-43) as pure functions of a
-- position. Map1Builder builds the parts from it, GoblinHorde reads hazards from it, and GoblinHordeClient stands
-- goblins, gems and projectiles on heightAt, so the horde walks up the same terraces and stairs the player jumps up.
-- Local coordinates: (0, 0) = the map centre, north = -Z, 600 x 600 studs. The ground is 6-stud tiles and every tile
-- has one kind and one height, so heightAt is exact (it samples the tile's centre).
--
--   centre      stone plaza, stepped pyramid (5 tiers x 5 studs) with 3-stud stairs down its south face
--   ring        a river (2 studs deep: wading slows) around the plaza, a bridge on each side
--   NW          the big mountain: 6 terraces of 5 studs, climbed by jumping ledge to ledge
--   NE          a mesa (3 x 6 studs) with a waterfall into a deep cenote
--   E           a low hill; SE stepping-stone pillars up to 20 studs; W raised ruin platforms
--   SW          the skeleton graveyard; S the spawn clearing and the path north to the plaza
--   edges       a 3-step cliff ring and jungle, so the valley reads as closed
--   hazards     thorns hurt, mud and water slow (players and goblins)
local Layout = {}

local TILE, HALF = 6, 300
Layout.TILE, Layout.HALF = TILE, HALF

local PLAZA = 60
local PYRAMID = { x = 0, z = -8, half = 30, tiers = 5, step = 5 } -- top is a 12 x 12 platform at 25 studs
local STAIRS = { half = 6, z0 = -2, z1 = 46 } -- 12 wide, from the top edge out over the plaza; 3-stud steps
local RIVER = { half = 100, radius = 32, width = 10, depth = -2 }
local BRIDGE = 9 -- half-width of the four bridges
local CENOTE = { x = 125, z = -110, rx = 22, rz = 18, depth = -4 }
local MOUNTAINS = { -- concentric terraces: `tiers` bands of `step` studs, highest in the middle
	{ x = -185, z = -185, rx = 95, rz = 85, tiers = 6, step = 5 }, -- NW mountain, 30 studs
	{ x = 190, z = -180, rx = 72, rz = 62, tiers = 3, step = 6 }, -- NE mesa, 18 studs
	{ x = 235, z = 70, rx = 50, rz = 70, tiers = 3, step = 5 }, -- E hill, 15 studs
}
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
local EDGE = { band = 12, steps = 3, step = 6 } -- cliff ring: 3 bands of 12 studs, 6 studs each, highest at the border
local JUNGLE = 66 -- trees grow within this far of the border (and on the mountains)

Layout.SPAWN, Layout.PYRAMID, Layout.CENOTE, Layout.GRAVEYARD, Layout.PILLARS = SPAWN, PYRAMID, CENOTE, GRAVEYARD, PILLARS
Layout.PLATFORMS, Layout.MOUNTAINS, Layout.RIVER, Layout.BRIDGE, Layout.STAIRS = PLATFORMS, MOUNTAINS, RIVER, BRIDGE, STAIRS

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
	local dx, dz = math.abs(x - PYRAMID.x), z - PYRAMID.z
	local ring = math.max(dx, math.abs(dz))
	local tier = if ring <= PYRAMID.half
		then math.min(PYRAMID.tiers, math.floor((PYRAMID.half - ring) / TILE) + 1) * PYRAMID.step
		else nil
	if dx <= STAIRS.half and z >= STAIRS.z0 + PYRAMID.z and z <= STAIRS.z1 + PYRAMID.z then
		local row = math.floor((STAIRS.z1 + PYRAMID.z - z) / TILE) -- 0 at the bottom step
		return math.max(math.min(3 * (row + 1), PYRAMID.tiers * PYRAMID.step), tier or 0) -- never below the tier it crosses
	end
	return tier
end

local function mountainHeight(x: number, z: number): number
	local h = 0
	for _, m in MOUNTAINS do
		local d = ellipse(x, z, m)
		if d < 1 then
			local t = 1 - math.sqrt(d) -- 0 at the rim, 1 at the centre
			h = math.max(h, m.step * math.min(m.tiers, math.floor(t * m.tiers * 1.4) + 1))
		end
	end
	local edge = HALF - math.max(math.abs(x), math.abs(z))
	if edge < EDGE.band * EDGE.steps then
		h = math.max(h, EDGE.step * (EDGE.steps - math.floor(edge / EDGE.band)))
	end
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
-- Graveyard / Spawn / Path / Mountain / Jungle / Grass.
local function kindAt(x: number, z: number): string
	if pyramidHeight(x, z) then
		local dx, dz = math.abs(x - PYRAMID.x), z - PYRAMID.z
		return if dx <= STAIRS.half and dz >= STAIRS.z0 then "Stairs" else "Pyramid"
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
	if mountainHeight(x, z) > 0 then
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

local function tileCentre(v: number): number
	return (math.floor((v + HALF) / TILE) + 0.5) * TILE - HALF
end

-- Local (x, z) -> kind and ground height (studs; the top of the ground at that tile).
function Layout.at(x: number, z: number): (string, number)
	if math.abs(x) >= HALF or math.abs(z) >= HALF then
		return "Outside", 0
	end
	local cx, cz = tileCentre(x), tileCentre(z)
	local kind = kindAt(cx, cz)
	if kind == "Pyramid" or kind == "Stairs" then
		return kind, pyramidHeight(cx, cz) :: number
	elseif kind == "Water" then
		return kind, RIVER.depth
	elseif kind == "Cenote" then
		return kind, CENOTE.depth
	elseif kind == "Bridge" then
		return kind, 1
	elseif kind == "Mountain" then
		return kind, mountainHeight(cx, cz)
	end
	return kind, 0
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
