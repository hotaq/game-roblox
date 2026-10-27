--!strict
-- Map1Builder (ModuleScript in ServerScriptService, never runs on its own): builds Map 1 "Forest ruins" (GAME-32) into Workspace.Map1 from the
-- ServerStorage.Map1Kit templates (the Blender kit: scripts/14_voxel_trees.py, 15_maya_ruins.py).
--
-- Layout (north = -Z), all relative to `origin`, 300 x 300 studs:
--   * ground of studded 6-stud Plastic tiles, classified per tile: forest floor, dirt path, clearing, plaza, pond;
--   * a 16-stud dirt path loop (rounded square) plus four spokes into the plaza, so there are no dead ends;
--   * a 100-stud temple plaza with the pyramid on its north side, stairs facing the open south half;
--   * clearings: broken shrine (N), colonnade (W), pond with fallen columns (E), spawn (S);
--   * dense forest everywhere else, thinner where it meets open ground so the edges read clearly.
-- Deterministic (fixed seeds): re-running gives the same map. Usage from the command bar / MCP:
--   require(game.ServerScriptService.Map1Builder).build()            -- everything, at (1000, 0, 0)
--   require(game.ServerScriptService.Map1Builder).build(nil, { "ground", "plaza" })   -- only some stages
local ServerStorage = game:GetService("ServerStorage")

local Builder = {}

local TILE, HALF = 6, 150
local PLAZA = 50 -- half-size of the square plaza
local LOOP_HALF, LOOP_R, PATH_W = 100, 40, 8 -- path loop: half-size, corner radius, half-width
local CLEARINGS = {
	Shrine = { x = 0, z = -112, rx = 34, rz = 24 },
	Colonnade = { x = -112, z = 0, rx = 24, rz = 40 },
	Pond = { x = 112, z = 0, rx = 28, rz = 40 },
	Spawn = { x = 0, z = 118, rx = 36, rz = 24 },
}
local POND = { x = 112, z = 0, rx = 15, rz = 26 }

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local SHADES = {
	Forest = { rgb(68, 124, 56), rgb(76, 134, 60), rgb(62, 116, 52) },
	Path = { rgb(124, 92, 62), rgb(116, 86, 58), rgb(132, 98, 66) },
	Clearing = { rgb(138, 104, 70), rgb(130, 98, 66), rgb(86, 142, 64) },
	Plaza = { rgb(158, 150, 132), rgb(140, 134, 118) },
	Foam = { rgb(232, 240, 240) },
	Water = { rgb(64, 156, 206) },
}

-- Signed distance from (x, z) to a rounded square of half-size h and corner radius r (negative inside).
local function roundedSquare(x: number, z: number, h: number, r: number): number
	local qx, qz = math.abs(x) - (h - r), math.abs(z) - (h - r)
	local outside = Vector2.new(math.max(qx, 0), math.max(qz, 0)).Magnitude
	return outside + math.min(math.max(qx, qz), 0) - r
end

local function inEllipse(x: number, z: number, e, grow: number?): boolean
	local g = grow or 0
	return ((x - e.x) / (e.rx + g)) ^ 2 + ((z - e.z) / (e.rz + g)) ^ 2 <= 1
end

-- What the ground is at (x, z): "Plaza", "Water", "Foam", "Clearing", "Path" or "Forest".
function Builder.classify(x: number, z: number): string
	if math.abs(x) <= PLAZA and math.abs(z) <= PLAZA then
		return "Plaza"
	end
	if inEllipse(x, z, POND) then
		return "Water"
	end
	if inEllipse(x, z, POND, 4) then
		return "Foam"
	end
	for _, c in CLEARINGS do
		if inEllipse(x, z, c) then
			return "Clearing"
		end
	end
	if math.abs(roundedSquare(x, z, LOOP_HALF, LOOP_R)) <= PATH_W then
		return "Path"
	end
	local spokeX = math.abs(x) <= PATH_W - 1 and math.abs(z) > PLAZA and math.abs(z) < 118
	local spokeZ = math.abs(z) <= PATH_W - 1 and math.abs(x) > PLAZA and math.abs(x) < 112
	if spokeX or spokeZ then
		return "Path"
	end
	return "Forest"
end

local function tile(parent: Instance, cf: CFrame, kind: string, rng: Random, x: number, z: number)
	local p = Instance.new("Part")
	p.Anchored, p.Size = true, Vector3.new(TILE, 2, TILE)
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Studs, Enum.SurfaceType.Smooth
	local shades = SHADES[kind]
	if kind == "Plaza" then
		p.Color = shades[(math.floor(x / TILE) + math.floor(z / TILE)) % 2 + 1]
	elseif kind == "Clearing" then
		p.Color = rng:NextNumber() < 0.35 and shades[3] or shades[rng:NextInteger(1, 2)]
	else
		p.Color = shades[rng:NextInteger(1, #shades)]
	end
	if kind == "Water" then
		p.Material, p.Transparency, p.Reflectance = Enum.Material.Glass, 0.15, 0.1
		p.TopSurface = Enum.SurfaceType.Smooth
		p.CFrame = cf * CFrame.new(x, -1.6, z) -- water sits a little below the shore
		p.CanCollide = false
	else
		p.Material = Enum.Material.Plastic
		p.CFrame = cf * CFrame.new(x, -1, z)
	end
	p.Name = kind
	p.Parent = parent
end

local function place(parent: Instance, name: string, cf: CFrame, scale: number?): Model
	local m = (ServerStorage.Map1Kit :: any)[name]:Clone() :: Model
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

local STAGES = {}

function STAGES.ground(map: Model, o: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "Ground"
	local rng = Random.new(1)
	for ix = 0, (2 * HALF) // TILE - 1 do
		local row = Instance.new("Folder") -- parent one row at a time so Studio never freezes
		for iz = 0, (2 * HALF) // TILE - 1 do
			local x, z = -HALF + TILE * (ix + 0.5), -HALF + TILE * (iz + 0.5)
			tile(row, o, Builder.classify(x, z), rng, x, z)
		end
		for _, p in row:GetChildren() do
			p.Parent = folder
		end
		row:Destroy()
		if ix % 5 == 0 then
			task.wait()
		end
	end
	folder.Parent = map
end

function STAGES.plaza(map: Model, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Plaza"
	f.Parent = map
	place(f, "Ruin_Pyramid", o * CFrame.new(0, 0, -50 + 30.5) * yaw(180)) -- stairs face south (+Z)
	for _, s in { -1, 1 } do
		place(f, "Ruin_Stela", o * CFrame.new(16 * s, 0, 16) * yaw(180)) -- flanking the foot of the stairs
		place(f, "Ruin_Pillar", o * CFrame.new(42 * s, 0, 42))
		place(f, "Ruin_Pillar", o * CFrame.new(42 * s, 0, 18))
		place(f, "Ruin_PillarBroken", o * CFrame.new(42 * s, 0, -6) * yaw(90 * s))
	end
	place(f, "Ruin_PillarFallen", o * CFrame.new(22, 0, 34) * yaw(25))
	place(f, "Ruin_Rubble", o * CFrame.new(-24, 0, 30))
	place(f, "Ruin_StelaBroken", o * CFrame.new(-30, 0, 4) * yaw(150))
end

function STAGES.clearings(map: Model, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Clearings"
	f.Parent = map
	-- Broken shrine (N): a U of ruined walls around a central stela.
	local s = CLEARINGS.Shrine
	place(f, "Ruin_Wall", o * CFrame.new(s.x, 0, s.z - 14))
	place(f, "Ruin_Wall", o * CFrame.new(s.x - 16, 0, s.z) * yaw(90))
	place(f, "Ruin_Wall", o * CFrame.new(s.x + 16, 0, s.z) * yaw(-90))
	place(f, "Ruin_Stela", o * CFrame.new(s.x, 0, s.z) * yaw(180))
	place(f, "Ruin_Rubble", o * CFrame.new(s.x + 10, 0, s.z + 10))
	-- Colonnade (W): two rows of pillars to kite around, every third one broken.
	local c = CLEARINGS.Colonnade
	for i = 0, 5 do
		for _, side in { -1, 1 } do
			local name = (i + (side > 0 and 1 or 0)) % 3 == 2 and "Ruin_PillarBroken" or "Ruin_Pillar"
			place(f, name, o * CFrame.new(c.x + 8 * side, 0, c.z - 30 + 12 * i) * yaw(90 * i))
		end
	end
	-- Pond (E): fallen columns across the water, rubble on the shore.
	local p = CLEARINGS.Pond
	place(f, "Ruin_PillarFallen", o * CFrame.new(p.x, 0, p.z - 8) * yaw(80))
	place(f, "Ruin_PillarFallen", o * CFrame.new(p.x - 4, 0, p.z + 14) * yaw(-20))
	place(f, "Ruin_Rubble", o * CFrame.new(p.x - 18, 0, p.z + 24))
	-- Spawn (S): an open clearing with a little rubble at its edge.
	local sp = CLEARINGS.Spawn
	place(f, "Ruin_StelaBroken", o * CFrame.new(sp.x + 24, 0, sp.z + 6) * yaw(200))
	place(f, "Ruin_Rubble", o * CFrame.new(sp.x - 26, 0, sp.z + 4))
	local marker = Instance.new("Part") -- where the run spawn will go (not a SpawnLocation yet)
	marker.Name, marker.Anchored, marker.CanCollide, marker.Transparency = "SpawnMarker", true, false, 1
	marker.Size, marker.CFrame = Vector3.new(6, 1, 6), o * CFrame.new(sp.x, 0.5, sp.z)
	marker.Parent = f
end

-- Distance (in studs, capped) from (x, z) to the nearest open (non-forest) ground, sampled on the tile grid.
local function openDistance(x: number, z: number, cap: number): number
	for r = 0, cap, TILE do
		for a = 0, 7 do
			local ang = a * math.pi / 4
			if Builder.classify(x + math.cos(ang) * r, z + math.sin(ang) * r) ~= "Forest" then
				return r
			end
		end
	end
	return cap
end

function STAGES.forest(map: Model, o: CFrame)
	local f = Instance.new("Folder")
	f.Name = "Forest"
	f.Parent = map
	local rng = Random.new(7)
	local counts = { Tree_Oak = 0, Tree_Pine = 0, Tree_Birch = 0, Tree_Bush = 0 }
	local SPACING = 13
	for gx = -HALF + 6, HALF - 6, SPACING do
		for gz = -HALF + 6, HALF - 6, SPACING do
			local x, z = gx + rng:NextNumber(-4, 4), gz + rng:NextNumber(-4, 4)
			if Builder.classify(x, z) == "Forest" then
				local d = openDistance(x, z, 18)
				local name
				if d < 9 then
					name = "Tree_Bush" -- forest edge: low bushes so the opening stays readable
				else
					local r = rng:NextNumber()
					name = r < 0.38 and "Tree_Pine" or r < 0.76 and "Tree_Oak" or r < 0.94 and "Tree_Birch" or "Tree_Bush"
				end
				place(f, name, o * CFrame.new(x, 0, z) * yaw(90 * rng:NextInteger(0, 3)), rng:NextNumber(0.9, 1.12))
				counts[name] += 1
			end
		end
		task.wait()
	end
	return counts
end

local ORDER = { "ground", "plaza", "clearings", "forest" }

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
	local report = {}
	for _, stage in stages or ORDER do
		local folderName = stage:sub(1, 1):upper() .. stage:sub(2)
		local old = (map :: Model):FindFirstChild(folderName)
		if old then
			old:Destroy()
		end
		report[stage] = STAGES[stage](map :: Model, o) or true
	end
	return report
end

return Builder
