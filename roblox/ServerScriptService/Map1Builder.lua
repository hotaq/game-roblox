-- Map1Builder (ModuleScript in ServerScriptService, never runs on its own): builds Map 1 "Jungle Temple Valley"
-- (GAME-43, replaced the 300 x 300 "Forest ruins") into Workspace.Map1. The layout itself (kinds, heights, hazards)
-- lives in ReplicatedStorage.Goblin.MapLayout, shared with the horde scripts, so the ground built here is exactly what
-- goblins walk on. Trees and ruins come from the ServerStorage.Map1Kit templates (scripts/14_voxel_trees.py,
-- 15_maya_ruins.py); the Meshy props from Map1Kit when present: Prop_Totem (asset 80849974035661, 20 studs tall,
-- pivot at its bottom centre), Prop_TempleGate (asset 137670247217292, 34 wide, opening along Z, ~10-stud walkable
-- gap), Prop_SkullShrine (asset 113206205477662: 8 plastic MeshParts, one per colour, from
-- scripts/26_plasticify_glb.py, plus 2 neon jade eyes; 40 wide, on the E hill), Prop_Pyramid (Meshy temple ruin
-- through 26_plasticify_glb.py stone: Stone/Step/Moss MeshParts, 60 wide, bottom-centre pivot), Prop_JadeHead, Prop_SkullRock.
-- Missing ones fall back to the part-built versions here; graves, thorns and bridges are built from parts.
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
	Ruin = { rgb(150, 154, 140), rgb(136, 142, 128), rgb(124, 132, 116) },
}
-- Mountain columns: a mosaic of rock, capped with a 1-stud layer of grass or moss where it isn't bare (cliffs, summits).
local ROCK = { rgb(132, 132, 116), rgb(120, 122, 108), rgb(144, 144, 128), rgb(110, 112, 100), rgb(126, 120, 104) }
local TOPS = {
	grass = { rgb(70, 140, 60), rgb(62, 128, 56), rgb(80, 150, 66) },
	moss = { rgb(108, 138, 84), rgb(96, 126, 76), rgb(118, 146, 92) },
}
local WATER = { Water = { color = rgb(70, 170, 214), top = -0.5 }, Cenote = { color = rgb(52, 150, 200), top = -0.6 } }
local STONE, STONE_DK, JADE, BONE = rgb(150, 154, 140), rgb(108, 112, 102), rgb(60, 176, 120), rgb(238, 228, 198)
-- The giant skull shrine on the E hill's summit (ground 10..18 there): sunk to y 12, no trees within `clear`.
local SHRINE = { x = 235, y = 12, z = 70, clear = 24 }

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

-- What tops a Mountain column at tile centre (x, z): grass on gentle foothills, moss higher up, nil = bare rock on
-- cliffs (a drop of 8+ to a neighbour) and summits. The treeline is ragged so it never reads as a contour ring.
local NEIGHBOURS = { Vector2.new(TILE, 0), Vector2.new(-TILE, 0), Vector2.new(0, TILE), Vector2.new(0, -TILE) }
local function surface(x: number, z: number, h: number): string?
	local drop = 0
	for _, d in NEIGHBOURS do
		local kind, hn = L.at(x + d.X, z + d.Y)
		if kind ~= "Outside" then
			drop = math.max(drop, h - hn)
		end
	end
	local alt = h + 12 * (hash(x, z) - 0.5)
	if drop >= 8 or alt >= 44 then
		return nil
	end
	return if alt >= 24 or drop >= 6 then "moss" else "grass"
end

local STAGES = {}

-- One part per run of tiles along Z with the same kind, height and shade (a 3-tile shade grid keeps runs long).
function STAGES.ground(map: Folder, o: CFrame)
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
	local pyramidMesh = ServerStorage.Map1Kit:FindFirstChild("Prop_Pyramid") ~= nil -- the mesh is the pyramid; plaza under it
	for ix = 0, n - 1 do
		local row = Instance.new("Folder") -- parent one row at a time so Studio never freezes
		local x = -HALF + TILE * (ix + 0.5)
		local start, key = 0, nil
		local function flush(iz1: number)
			if not key then
				return
			end
			local kind, h, shade, top = key.kind, key.h, key.shade, key.top
			local z0, z1 = -HALF + TILE * start, -HALF + TILE * iz1
			local b = if top then h - 1 else h -- the column stops under its cap
			local p = part(row, Vector3.new(TILE, b - BOTTOM, z1 - z0), o * CFrame.new(x, (b + BOTTOM) / 2, (z0 + z1) / 2), shade)
			-- Locked: Studio clicks pass through to the trees and props, and the ground (= MapLayout's heights, which the
			-- horde walks on) can't be dragged by accident.
			p.TopSurface, p.Name, p.Locked = Enum.SurfaceType.Studs, kind, true
			if top then
				part(row, Vector3.new(TILE, 1, z1 - z0), o * CFrame.new(x, h - 0.5, (z0 + z1) / 2), top,
					{ TopSurface = Enum.SurfaceType.Studs, Name = kind, Locked = true })
			end
			local w = WATER[kind]
			if w then -- see-through water over the bed, wading deep
				part(row, Vector3.new(TILE, 0.4, z1 - z0), o * CFrame.new(x, w.top - 0.2, (z0 + z1) / 2), w.color, {
					Material = Enum.Material.Glass, Transparency = 0.35, Reflectance = 0.1, CanCollide = false,
					CanQuery = false, CastShadow = false, Name = "Water", Locked = true,
				}).Parent = water
			end
		end
		for iz = 0, n - 1 do
			local z = -HALF + TILE * (iz + 0.5)
			local kind, h = L.at(x, z)
			if kind == "Pyramid" and pyramidMesh then
				kind, h = "Plaza", 0
			end
			local shade, top
			if kind == "Mountain" then
				shade = ROCK[math.floor(hash(ix, iz) * #ROCK) + 1]
				local s = surface(x, z, h)
				top = s and TOPS[s][math.floor(hash(ix // 2, iz // 2) * #TOPS[s]) + 1]
			else
				local shades = SHADES[kind] or SHADES.Grass
				shade = shades[math.floor(hash(ix // 3, iz // 3) * #shades) + 1]
			end
			if not key or key.kind ~= kind or key.h ~= h or key.shade ~= shade or key.top ~= top then
				flush(iz)
				start, key = iz, { kind = kind, h = h, shade = shade, top = top }
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

function STAGES.landmarks(map: Folder, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Landmarks"
	f.Parent = map
	-- The pyramid (Meshy temple ruin, bottom-centre pivot, 60 wide; without it the ground stage stacks its baked tile
	-- heights), a glowing jade crown and two braziers on the temple roof, and stelae at the foot of the south stairs.
	local P = L.PYRAMID
	place(f, "Prop_Pyramid", o * CFrame.new(P.x, 0, P.z))
	local top = o * CFrame.new(P.x, P.top, P.z)
	part(f, Vector3.new(6, 4, 6), top * CFrame.new(0, 2, 0), JADE, { Material = Enum.Material.Neon, Name = "JadeCrown" })
	for _, sx in { -4.5, 4.5 } do
		local b = part(f, Vector3.new(2, 3, 2), top * CFrame.new(sx, 1.5, 4), STONE_DK, { Name = "Brazier" })
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat, fire.Parent = 4, 6, b
	end
	place(f, "Ruin_Stela", on(o, P.x - 11, P.z + P.half + 4) * yaw(180))
	place(f, "Ruin_Stela", on(o, P.x + 11, P.z + P.half + 4) * yaw(180))
	-- totems at both ends of every bridge, gates where the south and north spokes leave the path loop
	local R = L.RIVER
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local side = Vector3.new(d.Z, 0, d.X) * (L.BRIDGE + 5)
		for _, r in { R.half - R.width - 6, R.half + R.width + 6 } do
			for _, s in { -1, 1 } do
				local p = d * r + side * s
				local cf = on(o, p.X, p.Z)
				if not place(f, "Prop_Totem", CFrame.lookAt(cf.Position, cf.Position - side * s)) then -- faces the road
					totem(f, cf)
				end
			end
		end
	end
	for _, z in { 175, -175 } do
		local cf = on(o, 0, z)
		if not place(f, "Prop_TempleGate", cf) then
			gate(f, cf)
		end
	end
	-- W ruin platforms and the lookout stones
	for i, p in L.PLATFORMS do
		place(f, if i == 1 then "Ruin_Wall" else "Ruin_PillarBroken", on(o, p.x, p.z - p.hz + 3))
	end
	place(f, "Ruin_Stela", on(o, L.PILLARS[#L.PILLARS].x, L.PILLARS[#L.PILLARS].z) * yaw(200))
	-- Meshy props (when imported into Map1Kit): the jade head watches the plaza from the north, the skull marks the graveyard
	place(f, "Prop_JadeHead", on(o, -34, -138) * yaw(160))
	place(f, "Prop_SkullRock", on(o, L.GRAVEYARD.x, L.GRAVEYARD.z) * yaw(-30))
	local shrine = (o * CFrame.new(SHRINE.x, SHRINE.y, SHRINE.z)).Position
	place(f, "Prop_SkullShrine", CFrame.lookAt(shrine, o.Position + Vector3.new(0, SHRINE.y, 0))) -- stares at the plaza
	-- A stepped mound of studded bricks over the mesh's low-poly rock base (about 40 x 40, 4.5 tall): grass on dirt.
	for bx = -26, 26, 4 do
		for bz = -26, 26, 4 do
			local d = math.max(math.abs(bx), math.abs(bz)) + (hash(bx + 50, bz + 50) - 0.5) * 5
			local top = SHRINE.y + (if d < 21 then 4.6 elseif d < 25 then 2.6 else 0.6)
			local x, z = SHRINE.x + bx, SHRINE.z + bz
			local _, g = L.at(x, z)
			if d < 28 and top > g then
				part(f, Vector3.new(4, top - 1 - (g - 2), 4), o * CFrame.new(x, (top - 1 + g - 2) / 2, z), rgb(110, 68, 40), { Name = "ShrineMound" })
				part(f, Vector3.new(4, 1, 4), o * CFrame.new(x, top - 0.5, z), if hash(bz, bx) < 0.5 then rgb(90, 166, 64) else rgb(70, 140, 60),
					{ Name = "ShrineMound", TopSurface = Enum.SurfaceType.Studs })
			end
		end
	end
	-- The waterfall: a stream from the top of the falls cliff down its tiers into the cenote, tile by tile towards it. A
	-- see-through slab on every step, a sheet down every drop, white foam and mist where it lands.
	local C, F = L.CENOTE, L.FALLS
	local BLUE = rgb(120, 200, 240)
	local WET = { Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, CanQuery = false, CastShadow = false, Name = "Waterfall" }
	local x, last = TILE * (math.floor(F.x / TILE) + 0.5), nil
	for z = TILE * (math.floor(F.z / TILE) + 0.5), C.z, TILE do
		local kind, h = L.at(x, z)
		local top = if kind == "Cenote" then WATER.Cenote.top else h
		if last and top < last then
			part(f, Vector3.new(8, last - top, 0.6), o * CFrame.new(x, (last + top) / 2, z - TILE / 2), BLUE, WET)
		end
		if kind == "Cenote" then
			for k = -1, 1 do
				local foam = part(f, Vector3.new(2.6, 0.8, 2.6), o * CFrame.new(x + k * 2.8, top + 0.2, z - TILE / 2 + 1.6) * yaw(k * 20),
					rgb(245, 250, 255), { CanCollide = false, CanQuery = false, Name = "Foam", TopSurface = Enum.SurfaceType.Studs })
				if k == 0 then
					local mist = Instance.new("ParticleEmitter")
					mist.Rate, mist.Lifetime, mist.Speed, mist.SpreadAngle = 30, NumberRange.new(0.8, 1.4), NumberRange.new(2, 5), Vector2.new(60, 60)
					mist.Size, mist.Transparency = NumberSequence.new(1.5, 4), NumberSequence.new(0.5, 1)
					mist.Color, mist.EmissionDirection = ColorSequence.new(rgb(230, 245, 255)), Enum.NormalId.Top
					mist.Parent = foam
				end
			end
			break
		end
		part(f, Vector3.new(8, 0.3, TILE), o * CFrame.new(x, h + 0.15, z), BLUE, WET)
		last = top
	end
	return #f:GetDescendants()
end

function STAGES.graveyard(map: Folder, o: CFrame)
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
function STAGES.hazards(map: Folder, o: CFrame)
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

function STAGES.bridges(map: Folder, o: CFrame)
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

-- Where the jungle grows: the jungle band, forest patches in the grass outside the river ring (48-stud noise cells,
-- FOREST of them), and the green mountain slopes (none on bare rock). The open lawns, paths and plaza stay clear.
local FOREST = 0.38
local function forested(kind: string, x: number, z: number, h: number, rng: Random): boolean
	if kind == "Jungle" then
		return true
	elseif kind == "Grass" then
		return math.max(math.abs(x), math.abs(z)) > 115 and hash(math.floor(x / 48), math.floor(z / 48)) < FOREST
	elseif kind == "Mountain" then
		local s = surface(TILE * (math.floor(x / TILE) + 0.5), TILE * (math.floor(z / TILE) + 0.5), h)
		return rng:NextNumber() < (if s == "grass" then 0.35 elseif s == "moss" then 0.1 else 0)
	end
	return false
end
local function nearShrine(x: number, z: number, r: number): boolean
	return (x - SHRINE.x) ^ 2 + (z - SHRINE.z) ^ 2 < (SHRINE.clear + r) ^ 2
end

-- Jungle: giant canopy trees, 2.4-3.6x the ~20-stud templates (50-80 studs), so they tower over a 5-stud player and
-- shade the floor, with bushes under them.
function STAGES.forest(map: Folder, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Forest"
	f.Parent = map
	local rng = Random.new(7)
	local n = 0
	for gx = -HALF + 13, HALF - 13, 26 do
		for gz = -HALF + 13, HALF - 13, 26 do
			local x, z = gx + rng:NextNumber(-8, 8), gz + rng:NextNumber(-8, 8)
			local kind, h = L.at(x, z)
			if forested(kind, x, z, h, rng) and not nearShrine(x, z, 14) then
				local r = rng:NextNumber()
				local name = r < 0.45 and "Tree_Oak" or r < 0.8 and "Tree_Pine" or "Tree_Birch"
				place(f, name, on(o, x, z) * yaw(90 * rng:NextInteger(0, 3)), rng:NextNumber(2.4, 3.6))
				n += 1
			end
		end
		task.wait()
	end
	for gx = -HALF + 5, HALF - 5, 10 do -- understory
		for gz = -HALF + 5, HALF - 5, 10 do
			local x, z = gx + rng:NextNumber(-3, 3), gz + rng:NextNumber(-3, 3)
			local kind, h = L.at(x, z)
			if rng:NextNumber() < 0.45 and forested(kind, x, z, h, rng) and not nearShrine(x, z, 4) then
				place(f, "Tree_Bush", on(o, x, z) * yaw(90 * rng:NextInteger(0, 3)), rng:NextNumber(1.4, 2.6))
				n += 1
			end
		end
		task.wait()
	end
	return n
end

-- Floor clutter so the ground isn't bare: grass tufts, flowers, ferns, pebbles, mushrooms. Small plastic bits with no
-- collision, queries or shadows; denser in the jungle. ponytail: ~1 part per 30 sq studs; cut the odds if FPS suffers.
function STAGES.decor(map: Folder, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Decor"
	local rng = Random.new(19)
	local GREENS = { rgb(62, 128, 56), rgb(98, 176, 70), rgb(80, 150, 66), rgb(45, 110, 55) }
	local FLOWERS = { rgb(235, 70, 70), rgb(250, 210, 60), rgb(245, 245, 240), rgb(150, 100, 215), rgb(245, 145, 45) }
	local LOOSE = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Name = "Decor" }
	local function pick(list)
		return list[rng:NextInteger(1, #list)]
	end
	local n = 0
	for ix = 0, 2 * HALF // TILE - 1 do
		for iz = 0, 2 * HALF // TILE - 1 do
			local x, z = -HALF + TILE * (ix + 0.5) + rng:NextNumber(-2.5, 2.5), -HALF + TILE * (iz + 0.5) + rng:NextNumber(-2.5, 2.5)
			local kind, h = L.at(x, z)
			local green = kind == "Grass" or kind == "Jungle" or kind == "Graveyard"
				or kind == "Mountain" and surface(TILE * (ix + 0.5) - HALF, TILE * (iz + 0.5) - HALF, h) ~= nil
			local odds = if kind == "Jungle" or forested(kind, x, z, h, rng) then 0.5 else 0.22
			if green and rng:NextNumber() < odds then
				local c = on(o, x, z) * yaw(rng:NextNumber(0, 360))
				local r = rng:NextNumber()
				if r < 0.4 then -- grass tuft
					for _ = 1, 3 do
						local tall = rng:NextNumber(1, 2.4)
						part(f, Vector3.new(0.35, tall, 0.35), c * CFrame.new(rng:NextNumber(-0.7, 0.7), tall / 2, rng:NextNumber(-0.7, 0.7))
							* CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), pick(GREENS), LOOSE)
					end
				elseif r < 0.62 then -- flower
					part(f, Vector3.new(0.2, 1.2, 0.2), c * CFrame.new(0, 0.6, 0), GREENS[1], LOOSE)
					part(f, Vector3.new(0.8, 0.4, 0.8), c * CFrame.new(0, 1.3, 0), pick(FLOWERS), LOOSE)
				elseif r < 0.8 then -- fern: three leaves splayed out
					for k = 0, 2 do
						part(f, Vector3.new(0.6, 0.2, 2.6), c * yaw(k * 120) * CFrame.new(0, 0.5, -1.1) * CFrame.Angles(math.rad(-25), 0, 0),
							pick(GREENS), LOOSE)
					end
				elseif r < 0.93 then -- pebbles
					local s = rng:NextNumber(1, 2.6)
					part(f, Vector3.new(s, s * 0.6, s * 0.8), c * CFrame.new(0, s * 0.2, 0), if rng:NextNumber() < 0.5 then STONE else STONE_DK, LOOSE)
				else -- mushroom
					part(f, Vector3.new(0.4, 0.8, 0.4), c * CFrame.new(0, 0.4, 0), BONE, LOOSE)
					part(f, Vector3.new(1.2, 0.5, 1.2), c * CFrame.new(0, 0.95, 0), rgb(215, 50, 45), LOOSE)
				end
				n += 1
			end
		end
		if ix % 10 == 0 then
			task.wait()
		end
	end
	f.Parent = map
	return n
end

-- Fake contact shadows under trees (real shadows are off at low graphics quality). Each disc lives inside its tree, so
-- moving, scaling or duplicating a tree by hand carries its shadow along.
function STAGES.shadows(map: Folder, o: CFrame)
	for _, m in (map:FindFirstChild("Forest") :: Folder):GetChildren() do
		local old = m:FindFirstChild("Shadow")
		if old then
			old:Destroy()
		end
		local _, size = m:GetBoundingBox()
		local p = m:GetPivot().Position
		local d = math.min(size.X, size.Z) * 0.85
		part(m, Vector3.new(0.1, d, d), CFrame.new(p.X, p.Y + 0.06, p.Z) * CFrame.Angles(0, 0, math.rad(90)), rgb(28, 52, 30), {
			Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Transparency = 0.45,
			CastShadow = false, CanCollide = false, CanQuery = false, CanTouch = false, Name = "Shadow",
		})
	end
end

-- Invisible walls on the four sides, and the (disabled) spawn pad in the south clearing.
function STAGES.edge(map: Folder, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Edge"
	f.Parent = map
	for i, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		part(f, if side.X ~= 0 then Vector3.new(2, 160, 2 * HALF + 4) else Vector3.new(2 * HALF + 4, 160, 2),
			o * CFrame.new(side * (HALF + 1) + Vector3.new(0, 70, 0)), Color3.new(), {
				Name = "Wall" .. i, Transparency = 1, CanQuery = false, CastShadow = false, Locked = true,
			})
	end
	local S = L.SPAWN
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Anchored, spawn.Enabled, spawn.Neutral, spawn.Duration = "Map1Spawn", true, false, true, 0
	spawn.Size, spawn.CFrame, spawn.Material = Vector3.new(8, 1, 8), on(o, S.x, S.z) * CFrame.new(0, 0.5, 0), Enum.Material.Plastic
	spawn.Color, spawn.TopSurface = rgb(176, 168, 148), Enum.SurfaceType.Studs
	spawn.Parent = f
end

local ORDER = { "ground", "landmarks", "graveyard", "hazards", "bridges", "forest", "shadows", "decor", "edge" }

-- Builds (or rebuilds) Workspace.Map1 at `origin` (default (1000, 0, 0)). `stages` picks a subset of ORDER; existing
-- folders of the stages being rebuilt are replaced, others are kept. A stage folder with the HandEdited attribute (the
-- owner placed things in it by hand) is skipped by a full build; only naming its stage rebuilds it.
function Builder.build(origin: Vector3?, stages: { string }?)
	local o = CFrame.new(origin or Vector3.new(1000, 0, 0))
	-- A Folder, not a Model: Studio selects the outermost Model on click, so a Model map made every click pick the whole
	-- map instead of the tree or part under the cursor.
	local map = workspace:FindFirstChild("Map1") :: Folder?
	if not map then
		map = Instance.new("Folder")
		map.Name = "Map1"
		map.Parent = workspace
	end
	local model = map :: Folder
	-- Arena attributes read by GoblinHorde's arena() and MapLayout's world helpers: the Map1Pad sends runs here.
	model:SetAttribute("Center", o.Position)
	model:SetAttribute("Size", 2 * HALF)
	model:SetAttribute("Spawn", o.Position + Vector3.new(L.SPAWN.x, 0, L.SPAWN.z))
	local report = {}
	for _, stage in stages or ORDER do
		local folderName = stage:sub(1, 1):upper() .. stage:sub(2)
		local kept = model:FindFirstChild(folderName)
		if not stages and kept and kept:GetAttribute("HandEdited") then
			report[stage] = "kept (HandEdited)"
			continue
		end
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
