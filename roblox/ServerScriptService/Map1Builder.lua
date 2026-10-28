-- Map1Builder (ModuleScript in ServerScriptService, never runs on its own): builds Map 1 "Jungle Temple Valley"
-- (GAME-43, replaced the 300 x 300 "Forest ruins") into Workspace.Map1. The layout itself (kinds, heights, hazards)
-- lives in ReplicatedStorage.Goblin.MapLayout, shared with the horde scripts, so the ground built here is exactly what
-- goblins walk on. Trees and ruins come from the ServerStorage.Map1Kit templates (scripts/14_voxel_trees.py,
-- 15_maya_ruins.py); the jade head and the stone skull (Meshy) from Map1Kit.Prop_JadeHead / Prop_SkullRock when
-- present; totems, the temple gate, graves, thorns and bridges are built from parts here.
-- Deterministic (fixed seeds). Usage from the command bar / MCP:
--   require(game.ServerScriptService.Map1Builder).build()                      -- everything, at (1000, 0, 0)
--   require(game.ServerScriptService.Map1Builder).build(nil, { "props" })      -- only some stages
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local L = require(ReplicatedStorage:WaitForChild("Goblin"):WaitForChild("MapLayout"))

local Builder = {}
local TILE, HALF = L.TILE, L.HALF
local BOTTOM = -6 -- every ground column reaches down to here

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local SHADES = {
	Grass = { rgb(98, 176, 70), rgb(90, 166, 64), rgb(106, 184, 76) },
	Jungle = { rgb(62, 128, 56), rgb(56, 118, 52), rgb(68, 136, 60) },
	Path = { rgb(150, 112, 72), rgb(140, 104, 66), rgb(158, 118, 78) },
	Plaza = { rgb(176, 168, 148), rgb(160, 152, 134) },
	Pyramid = { rgb(150, 154, 140), rgb(136, 142, 128) },
	Stairs = { rgb(176, 170, 152) },
	Shore = { rgb(214, 196, 150), rgb(204, 186, 140) },
	Water = { rgb(72, 120, 110) }, -- the river bed, under a see-through water surface
	Cenote = { rgb(40, 80, 92) },
	Bridge = { rgb(140, 92, 54), rgb(128, 84, 48) },
	Thorns = { rgb(92, 58, 72), rgb(84, 52, 66) },
	Mud = { rgb(96, 70, 46), rgb(88, 64, 42) },
	Graveyard = { rgb(96, 120, 84), rgb(88, 110, 78) },
	Spawn = { rgb(176, 168, 148), rgb(166, 158, 140) },
	Mountain = { rgb(120, 150, 92), rgb(132, 132, 116), rgb(110, 140, 86), rgb(124, 124, 110) }, -- by terrace
}
local WATER = { Water = { color = rgb(70, 170, 214), top = -0.5 }, Cenote = { color = rgb(52, 150, 200), top = -0.6 } }
local STONE, STONE_DK, JADE, BONE = rgb(150, 154, 140), rgb(108, 112, 102), rgb(60, 176, 120), rgb(238, 228, 198)

local function hash(a: number, b: number): number -- deterministic 0..1 noise for shades and jitter
	local n = bit32.bxor(a * 73856093 % 4294967296, b * 19349663 % 4294967296)
	n = bit32.bxor(n, bit32.rshift(n, 13)) * 1274126177 % 4294967296
	return bit32.bxor(n, bit32.rshift(n, 16)) % 1000 / 1000
end

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Anchored, p.Size, p.CFrame, p.Color = true, size, cf, color
	p.Material, p.TopSurface, p.BottomSurface = Enum.Material.Plastic, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function place(parent: Instance, name: string, cf: CFrame, scale: number?): Model?
	local template = ServerStorage.Map1Kit:FindFirstChild(name)
	if not template then
		return nil
	end
	local m = template:Clone() :: Model
	if scale and scale ~= 1 then
		m:ScaleTo(scale)
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

local function yaw(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

-- Ground at local (x, z) as a world CFrame on top of the ground.
local function on(o: CFrame, x: number, z: number): CFrame
	local _, h = L.at(x, z)
	return o * CFrame.new(x, h, z)
end

local STAGES = {}

-- One part per run of tiles along Z with the same kind, height and shade (a 3-tile shade grid keeps runs long).
function STAGES.ground(map: Model, o: CFrame)
	-- Old terrain under the map area (it covered the west river and pools); only the map's own box is cleared.
	workspace.Terrain:FillBlock(o * CFrame.new(0, 25, 0), Vector3.new(2 * HALF + 8, 70, 2 * HALF + 8), Enum.Material.Air)
	-- The lobby Baseplate (top at y = -0.2) reached under the map's west half and hid the river; trim it to end
	-- before the map. Everything else on it (lobby, StressZone, SwordFXZone) is further west.
	local plate = workspace:FindFirstChild("Baseplate")
	if plate and plate:IsA("BasePart") then
		local xmin, xmax, edge = plate.Position.X - plate.Size.X / 2, plate.Position.X + plate.Size.X / 2, o.X - HALF - 4
		if xmax > edge and xmin < edge then
			plate.Size = Vector3.new(edge - xmin, plate.Size.Y, plate.Size.Z)
			plate.Position = Vector3.new((xmin + edge) / 2, plate.Position.Y, plate.Position.Z)
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "Ground"
	local water = Instance.new("Folder")
	water.Name = "WaterSurface"
	local n = 2 * HALF // TILE
	for ix = 0, n - 1 do
		local row = Instance.new("Folder") -- parent one row at a time so Studio never freezes
		local x = -HALF + TILE * (ix + 0.5)
		local start, key = 0, nil
		local function flush(iz1: number)
			if not key then
				return
			end
			local kind, h, shade = key.kind, key.h, key.shade
			local z0, z1 = -HALF + TILE * start, -HALF + TILE * iz1
			local p = part(row, Vector3.new(TILE, h - BOTTOM, z1 - z0), o * CFrame.new(x, (h + BOTTOM) / 2, (z0 + z1) / 2), shade)
			p.TopSurface, p.Name = Enum.SurfaceType.Studs, kind
			local w = WATER[kind]
			if w then -- see-through water over the bed, wading deep
				part(row, Vector3.new(TILE, 0.4, z1 - z0), o * CFrame.new(x, w.top - 0.2, (z0 + z1) / 2), w.color, {
					Material = Enum.Material.Glass, Transparency = 0.35, Reflectance = 0.1, CanCollide = false,
					CanQuery = false, CastShadow = false, Name = "Water",
				}).Parent = water
			end
		end
		for iz = 0, n - 1 do
			local z = -HALF + TILE * (iz + 0.5)
			local kind, h = L.at(x, z)
			local shades = SHADES[kind] or SHADES.Grass
			local pick = if kind == "Mountain" then (h // 5) % #shades + 1 else math.floor(hash(ix // 3, iz // 3) * #shades) + 1
			local shade = shades[pick]
			if not key or key.kind ~= kind or key.h ~= h or key.shade ~= shade then
				flush(iz)
				start, key = iz, { kind = kind, h = h, shade = shade }
			end
		end
		flush(n)
		for _, p in row:GetChildren() do
			p.Parent = folder
		end
		row:Destroy()
		if ix % 4 == 0 then
			task.wait()
		end
	end
	folder.Parent = map
	water.Parent = map
	return #folder:GetChildren()
end

-- A carved stone totem: a base and three stacked faces with jade inlays and a jade gem on top.
local function totem(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Totem"
	part(m, Vector3.new(8, 2, 8), cf * CFrame.new(0, 1, 0), STONE_DK)
	for i = 0, 2 do
		local y = 2 + 6 * i + 3
		local face = cf * CFrame.new(0, y, 0)
		part(m, Vector3.new(6, 6, 6), face, STONE, { TopSurface = Enum.SurfaceType.Studs })
		for _, sx in { -1.4, 1.4 } do
			part(m, Vector3.new(1.4, 1.2, 0.4), face * CFrame.new(sx, 0.9, -3), rgb(24, 30, 26)) -- eyes
		end
		part(m, Vector3.new(3, 0.8, 0.4), face * CFrame.new(0, -1.4, -3), rgb(24, 30, 26)) -- mouth
		part(m, Vector3.new(6.2, 0.8, 6.2), face * CFrame.new(0, -2.6, 0), JADE, { Material = Enum.Material.SmoothPlastic }) -- inlay band
	end
	part(m, Vector3.new(2.4, 2.4, 2.4), cf * CFrame.new(0, 21.2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), JADE,
		{ Material = Enum.Material.Neon })
	m.Parent = parent
	return m
end

-- A ruined Maya gateway: two carved pillars, a stepped lintel with a broken corner, hanging vines, fallen blocks.
local function gate(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "TempleGate"
	for _, sx in { -10, 10 } do
		for i = 0, 3 do
			part(m, Vector3.new(6, 5, 6), cf * CFrame.new(sx, 2.5 + 5 * i, 0), if i % 2 == 0 then STONE else STONE_DK,
				{ TopSurface = Enum.SurfaceType.Studs })
			part(m, Vector3.new(6.2, 1, 6.2), cf * CFrame.new(sx, 4.5 + 5 * i, 0), JADE, { Material = Enum.Material.SmoothPlastic })
		end
	end
	part(m, Vector3.new(28, 4, 8), cf * CFrame.new(-1.5, 22, 0), STONE, { TopSurface = Enum.SurfaceType.Studs }) -- lintel (right end broken off)
	part(m, Vector3.new(18, 3, 6), cf * CFrame.new(-4, 25.5, 0), STONE_DK)
	for i = -3, 3 do
		part(m, Vector3.new(1.4, 1.4, 0.4), cf * CFrame.new(-1.5 + i * 3.4, 22, -4.1), JADE, { Material = Enum.Material.SmoothPlastic })
	end
	for i, vx in { -6, -2, 3, 7 } do -- vines hanging across the opening
		part(m, Vector3.new(0.6, 4 + i * 1.5, 0.6), cf * CFrame.new(vx, 20 - (4 + i * 1.5) / 2, -2), rgb(54, 128, 48),
			{ CanCollide = false })
	end
	for i, p in { Vector3.new(15, 2, 6), Vector3.new(17, 1.5, -4), Vector3.new(13, 1.5, -7) } do
		part(m, Vector3.new(4, 3, 4), cf * CFrame.new(p) * CFrame.Angles(0.3 * i, 0.7 * i, 0.2), STONE) -- fallen blocks
	end
	m.Parent = parent
	return m
end

function STAGES.landmarks(map: Model, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Landmarks"
	f.Parent = map
	-- pyramid crown: a glowing jade block and two braziers on the top platform
	local P = L.PYRAMID
	local top = o * CFrame.new(P.x, P.tiers * P.step, P.z)
	part(f, Vector3.new(8, 5, 8), top * CFrame.new(0, 2.5, -2), JADE, { Material = Enum.Material.Neon, Name = "JadeCrown" })
	for _, sx in { -4.5, 4.5 } do
		local b = part(f, Vector3.new(2, 3, 2), top * CFrame.new(sx, 1.5, 4.5), STONE_DK, { Name = "Brazier" })
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat, fire.Parent = 4, 6, b
	end
	place(f, "Ruin_Stela", on(o, P.x - 12, P.z + L.STAIRS.z1 - 2) * yaw(180)) -- flanking the foot of the stairs
	place(f, "Ruin_Stela", on(o, P.x + 12, P.z + L.STAIRS.z1 - 2) * yaw(180))
	-- totems at both ends of every bridge, gates where the south and north spokes leave the path loop
	local R = L.RIVER
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local side = Vector3.new(d.Z, 0, d.X) * (L.BRIDGE + 5)
		for _, r in { R.half - R.width - 6, R.half + R.width + 6 } do
			for _, s in { -1, 1 } do
				local p = d * r + side * s
				totem(f, on(o, p.X, p.Z))
			end
		end
	end
	gate(f, on(o, 0, 175))
	gate(f, on(o, 0, -175))
	-- W ruin platforms and the lookout stones
	for i, p in L.PLATFORMS do
		place(f, if i == 1 then "Ruin_Wall" else "Ruin_PillarBroken", on(o, p.x, p.z - p.hz + 3))
	end
	place(f, "Ruin_Stela", on(o, L.PILLARS[#L.PILLARS].x, L.PILLARS[#L.PILLARS].z) * yaw(200))
	-- Meshy props (when imported into Map1Kit): the jade head watches the plaza from the north, the skull marks the graveyard
	place(f, "Prop_JadeHead", on(o, -34, -138) * yaw(160))
	place(f, "Prop_SkullRock", on(o, L.GRAVEYARD.x, L.GRAVEYARD.z) * yaw(-30))
	-- the NE mesa's waterfall into the cenote
	local C = L.CENOTE
	local fall = part(f, Vector3.new(10, 22, 2), o * CFrame.new(C.x + 12, 8, C.z - 22) * yaw(-35), rgb(120, 200, 240), {
		Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, Name = "Waterfall",
	})
	local mist = Instance.new("ParticleEmitter")
	mist.Rate, mist.Lifetime, mist.Speed, mist.SpreadAngle = 30, NumberRange.new(0.8, 1.4), NumberRange.new(2, 5), Vector2.new(60, 60)
	mist.Size, mist.Transparency = NumberSequence.new(1.5, 4), NumberSequence.new(0.5, 1)
	mist.Color, mist.EmissionDirection = ColorSequence.new(rgb(230, 245, 255)), Enum.NormalId.Bottom
	mist.Parent = fall
	return #f:GetDescendants()
end

function STAGES.graveyard(map: Model, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Graveyard"
	f.Parent = map
	local G = L.GRAVEYARD
	local rng = Random.new(11)
	for i = 1, 26 do -- leaning tombstones
		local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber(0.08, 0.9))
		local x, z = G.x + math.cos(a) * G.rx * r, G.z + math.sin(a) * G.rz * r
		local kind = L.at(x, z)
		if kind == "Graveyard" then
			local h = rng:NextNumber(3, 5)
			part(f, Vector3.new(3, h, 1), on(o, x, z) * yaw(rng:NextNumber(-25, 25)) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, 0)
				* CFrame.new(0, h / 2 - 0.3, 0), if i % 3 == 0 then STONE_DK else STONE, { TopSurface = Enum.SurfaceType.Studs })
		end
	end
	for i = 1, 10 do -- bone piles
		local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber(0.1, 0.8))
		local c = on(o, G.x + math.cos(a) * G.rx * r, G.z + math.sin(a) * G.rz * r)
		for k = 1, 5 do
			part(f, Vector3.new(0.6, 0.6, rng:NextNumber(2, 3.2)), c * CFrame.new(rng:NextNumber(-1.5, 1.5), 0.3 + 0.3 * (k % 2), rng:NextNumber(-1.5, 1.5))
				* yaw(rng:NextNumber(0, 180)), BONE, { CanCollide = false })
		end
	end
	return #f:GetChildren()
end

-- Thorn patches: clusters of dark spiky bushes so the hazard reads from afar.
function STAGES.hazards(map: Model, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Hazards"
	f.Parent = map
	for gx = -HALF + 3, HALF - 3, 5 do
		for gz = -HALF + 3, HALF - 3, 5 do
			local x, z = gx + (hash(gx, gz) - 0.5) * 3, gz + (hash(gz, gx) - 0.5) * 3
			if L.at(x, z) == "Thorns" then
				local c = on(o, x, z)
				part(f, Vector3.new(2.6, 1.8, 2.6), c * CFrame.new(0, 0.9, 0) * yaw(hash(gx, 7) * 90), rgb(70, 40, 60))
				for k = 0, 3 do
					local spike = Instance.new("WedgePart")
					spike.Anchored, spike.Size, spike.Color = true, Vector3.new(0.5, 1.6, 0.8), rgb(150, 50, 70)
					spike.CFrame = c * yaw(k * 90 + hash(gz, k) * 40) * CFrame.new(0, 2.4, 0.6)
					spike.Parent = f
				end
			end
		end
	end
	return #f:GetChildren()
end

function STAGES.bridges(map: Model, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Bridges"
	f.Parent = map
	local R = L.RIVER
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local side = Vector3.new(d.Z, 0, d.X)
		for k = -3, 3 do -- rail posts along both sides
			for _, s in { -1, 1 } do
				local p = d * (R.half + k * 3.4) + side * s * (L.BRIDGE - 0.5)
				part(f, Vector3.new(0.8, 3, 0.8), on(o, p.X, p.Z) * CFrame.new(0, 1.5, 0), rgb(110, 72, 42))
			end
		end
		for _, s in { -1, 1 } do
			local p = d * R.half + side * s * (L.BRIDGE - 0.5)
			local len = 2 * (R.width + 2)
			part(f, if d.X ~= 0 then Vector3.new(len, 0.6, 0.6) else Vector3.new(0.6, 0.6, len), on(o, p.X, p.Z) * CFrame.new(0, 3, 0),
				rgb(128, 84, 48))
		end
	end
	return #f:GetChildren()
end

-- Jungle: trees on the jungle band and on the mountains, a few groves out in the grass.
function STAGES.forest(map: Model, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Forest"
	f.Parent = map
	local rng = Random.new(7)
	local n = 0
	for gx = -HALF + 7, HALF - 7, 12 do
		for gz = -HALF + 7, HALF - 7, 12 do
			local x, z = gx + rng:NextNumber(-4, 4), gz + rng:NextNumber(-4, 4)
			local kind = L.at(x, z)
			local grove = kind == "Grass" and hash(math.floor(x / 48), math.floor(z / 48)) < 0.12
			local mountain = kind == "Mountain" and rng:NextNumber() < 0.2 -- sparse, so the ledges stay readable
			if kind == "Jungle" or grove or mountain then
				local r = rng:NextNumber()
				local name = r < 0.4 and "Tree_Oak" or r < 0.7 and "Tree_Pine" or r < 0.85 and "Tree_Birch" or "Tree_Bush"
				place(f, name, on(o, x, z) * yaw(90 * rng:NextInteger(0, 3)), rng:NextNumber(0.95, 1.25))
				n += 1
			end
		end
		task.wait()
	end
	return n
end

-- Fake contact shadows under trees (real shadows are off at low graphics quality).
function STAGES.shadows(map: Model, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Shadows"
	for _, m in (map:FindFirstChild("Forest") :: Folder):GetChildren() do
		local _, size = m:GetBoundingBox()
		local p = m:GetPivot().Position
		local d = math.min(size.X, size.Z) * 0.85
		part(f, Vector3.new(0.1, d, d), CFrame.new(p.X, p.Y + 0.06, p.Z) * CFrame.Angles(0, 0, math.rad(90)), rgb(28, 52, 30), {
			Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Transparency = 0.45,
			CastShadow = false, CanCollide = false, CanQuery = false, CanTouch = false, Name = "Shadow",
		})
	end
	f.Parent = map
end

-- Invisible walls on the four sides, and the (disabled) spawn pad in the south clearing.
function STAGES.edge(map: Model, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Edge"
	f.Parent = map
	for i, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		part(f, if side.X ~= 0 then Vector3.new(2, 160, 2 * HALF + 4) else Vector3.new(2 * HALF + 4, 160, 2),
			o * CFrame.new(side * (HALF + 1) + Vector3.new(0, 70, 0)), Color3.new(), {
				Name = "Wall" .. i, Transparency = 1, CanQuery = false, CastShadow = false,
			})
	end
	local S = L.SPAWN
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Anchored, spawn.Enabled, spawn.Neutral, spawn.Duration = "Map1Spawn", true, false, true, 0
	spawn.Size, spawn.CFrame, spawn.Material = Vector3.new(8, 1, 8), on(o, S.x, S.z) * CFrame.new(0, 0.5, 0), Enum.Material.Plastic
	spawn.Color, spawn.TopSurface = rgb(176, 168, 148), Enum.SurfaceType.Studs
	spawn.Parent = f
end

local ORDER = { "ground", "landmarks", "graveyard", "hazards", "bridges", "forest", "shadows", "edge" }

-- Builds (or rebuilds) Workspace.Map1 at `origin` (default (1000, 0, 0)). `stages` picks a subset of ORDER; existing
-- folders of the stages being rebuilt are replaced, others are kept.
function Builder.build(origin: Vector3?, stages: { string }?)
	local o = CFrame.new(origin or Vector3.new(1000, 0, 0))
	local map = workspace:FindFirstChild("Map1") :: Model?
	if not map then
		map = Instance.new("Model")
		map.Name = "Map1"
		map.Parent = workspace
	end
	local model = map :: Model
	-- Arena attributes read by GoblinHorde's arena() and MapLayout's world helpers: the Map1Pad sends runs here.
	model:SetAttribute("Center", o.Position)
	model:SetAttribute("Size", 2 * HALF)
	model:SetAttribute("Spawn", o.Position + Vector3.new(L.SPAWN.x, 0, L.SPAWN.z))
	local report = {}
	for _, stage in stages or ORDER do
		local folderName = stage:sub(1, 1):upper() .. stage:sub(2)
		for _, name in { folderName, if stage == "ground" then "WaterSurface" else nil } do
			local old = model:FindFirstChild(name :: string)
			if old then
				old:Destroy()
			end
		end
		report[stage] = STAGES[stage](model, o) or true
	end
	return report
end

return Builder
