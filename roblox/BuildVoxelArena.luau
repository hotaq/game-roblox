-- BuildVoxelArena.luau: run in the Command Bar (Edit mode). Safe to re-run: it rebuilds workspace.VoxelArena.
-- "Voxel Jungle" art direction: pixel-textured blocks (MaterialVariants from scripts/10_voxel_textures.py,
-- 4 studs per texture tile = 4 texels per stud everywhere), a mossy stone plaza for the goblins, ruin walls and
-- torch pillars, a stepped temple, mossy cliffs with a waterfall, jungle trees, palms and bushes.
-- Undo: delete workspace.VoxelArena and MaterialService.Voxel_* (the Baseplate is only lowered and retextured).
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local rng = Random.new(11)

-- Uploaded 2026-10-26 (bright kid-friendly set) from goblin/textures/voxel/*.png. Re-upload and update these if the textures change.
local TEX = {
	grass = { Enum.Material.Grass, "rbxassetid://79066132131862" },
	dirt = { Enum.Material.Ground, "rbxassetid://129498154615302" },
	mossy_stone = { Enum.Material.Slate, "rbxassetid://77385969309565" },
	ruin_brick = { Enum.Material.Brick, "rbxassetid://89874612685670" },
	bark = { Enum.Material.Wood, "rbxassetid://78389765565159" },
	leaves = { Enum.Material.LeafyGrass, "rbxassetid://134893957874335" },
	water = { Enum.Material.Plastic, "rbxassetid://140399168563119" },
}
for name, t in TEX do
	local v = MaterialService:FindFirstChild("Voxel_" .. name) or Instance.new("MaterialVariant")
	v.Name, v.BaseMaterial, v.ColorMap = "Voxel_" .. name, t[1], t[2]
	v.StudsPerTile, v.MaterialPattern = 4, Enum.MaterialPattern.Regular -- Regular: no random rotation, pixels stay on grid
	v.Parent = MaterialService
end

local X0, X1, Z0, Z1 = -64, 64, -80, 36 -- floor extent; the showcase grid sits at x -27..27, z -12..-30
local AMBER = Color3.fromRGB(252, 157, 54)

local old = workspace:FindFirstChild("VoxelArena")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "VoxelArena"
root.Parent = workspace

local function group(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	return m
end

-- tint < 1 darkens the texture a little so neighbouring blocks don't look copy-pasted
local function block(parent, size: Vector3, pos: Vector3, tex: string, tint: number?, collide: boolean?)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide = true, collide ~= false
	p.CastShadow = size.Y > 0.6
	p.Size, p.Position = size, pos
	p.Material, p.MaterialVariant = TEX[tex][1], "Voxel_" .. tex
	local k = tint or rng:NextNumber(0.94, 1)
	p.Color = Color3.new(k, k, k)
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function inArena(x, z)
	return math.abs(x) <= 34 and z <= -6 and z >= -38
end
local function inPath(x, z)
	return math.abs(x) <= 6 and z > -6 and z <= 24
end
local function inPool(x, z)
	return x >= -58 and x <= -38 and z >= -74 and z <= -58
end
local function inTemple(x, z)
	return math.abs(x) <= 22 and z <= -44 and z >= -80
end

-- Ground height in 2-stud steps (walkable): flat where the goblins, path, temple and pool are, rising into
-- grass-block terraces toward the cliffs (the Islands/BedWars look: green tops, dirt sides).
local function height(x: number, z: number): number
	local nearPlay = (math.abs(x) <= 42 and z <= 2 and z >= -46)
		or (math.abs(x) <= 16 and z > -6 and z <= 28)
		or (math.abs(x) <= 26 and z <= -40)
		or (x >= -62 and x <= -34 and z >= -80 and z <= -54)
	if nearPlay then
		return 0
	end
	local edge = math.max(0, 1 - math.min(x - X0, X1 - x, z - Z0, Z1 - z) / 24) -- 0 inside, 1 at the edge
	local n = math.noise(x / 36, z / 36, 0.37) + edge * 1.4
	return math.clamp(math.floor(n * 3 + 0.8), 0, 4) * 2
end

-- Floor: a grass (or stone/dirt) cap on top, a dirt column under it when the ground is raised.
-- One Model per column so each Parent write stays small.
for x = X0, X1 - 4, 4 do
	local col = group("Floor")
	for z = Z0, Z1 - 4, 4 do
		local cx, cz = x + 2, z + 2
		local h = height(cx, cz)
		if inPool(cx, cz) then
			local w = block(col, Vector3.new(4, 1, 4), Vector3.new(cx, -0.8, cz), "water", 1)
			w.Transparency, w.CastShadow = 0.15, false
		else
			local top = if inArena(cx, cz) then "mossy_stone" elseif inPath(cx, cz) or rng:NextNumber() < 0.04 then "dirt" else "grass"
			block(col, Vector3.new(4, 1, 4), Vector3.new(cx, h - 0.5, cz), top)
			if h > 0 then
				block(col, Vector3.new(4, h, 4), Vector3.new(cx, h / 2 - 1, cz), "dirt") -- y -1 .. h-1, under the cap
			end
		end
	end
	col.Parent = root
	task.wait()
end

local function torch(pos: Vector3)
	local m = group("Torch")
	block(m, Vector3.new(1, 3, 1), pos + Vector3.new(0, 1.5, 0), "bark", 0.8)
	local flame = Instance.new("Part")
	flame.Anchored, flame.CanCollide, flame.CastShadow = true, false, false
	flame.Size, flame.Position = Vector3.new(1, 1, 1), pos + Vector3.new(0, 3.5, 0)
	flame.Material, flame.Color = Enum.Material.Neon, AMBER
	flame.Parent = m
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = AMBER, 14, 1.4, false
	light.Parent = flame
	m.Parent = root
end

-- Ruin walls around the plaza: broken segments of brick, mossy tops, gaps for the spawn path.
local ruins = group("Ruins")
local function wallRun(fromV: Vector3, toV: Vector3)
	local dir = (toV - fromV).Unit
	local len = (toV - fromV).Magnitude
	for d = 0, len - 4, 4 do
		local c = fromV + dir * (d + 2)
		if not inPath(c.X, c.Z + 2) and rng:NextNumber() < 0.78 then
			local h = rng:NextInteger(1, 3) * 2
			local size = if math.abs(dir.X) > 0.5 then Vector3.new(4, h, 2) else Vector3.new(2, h, 4)
			block(ruins, size, Vector3.new(c.X, h / 2, c.Z), "ruin_brick")
			if rng:NextNumber() < 0.45 then -- moss cap
				block(ruins, Vector3.new(size.X, 0.5, size.Z), Vector3.new(c.X, h + 0.25, c.Z), "leaves", nil, false)
			end
		end
	end
end
wallRun(Vector3.new(-36, 0, -40), Vector3.new(36, 0, -40))
wallRun(Vector3.new(-36, 0, -4), Vector3.new(36, 0, -4))
wallRun(Vector3.new(-37, 0, -40), Vector3.new(-37, 0, -4))
wallRun(Vector3.new(37, 0, -40), Vector3.new(37, 0, -4))
for _, p in { Vector3.new(-37, 0, -40), Vector3.new(37, 0, -40), Vector3.new(-37, 0, -4), Vector3.new(37, 0, -4), Vector3.new(-8, 0, -4), Vector3.new(8, 0, -4) } do
	block(ruins, Vector3.new(3, 10, 3), p + Vector3.new(0, 5, 0), "ruin_brick")
	torch(p + Vector3.new(0, 10, 0))
end
ruins.Parent = root

-- Stepped temple behind the plaza, stairs facing the goblins.
local temple = group("Temple")
local TZ = -64
for i = 0, 4 do
	local w, d = 40 - i * 7, 28 - i * 5
	block(temple, Vector3.new(w, 3, d), Vector3.new(0, 1.5 + i * 3, TZ), "ruin_brick", 0.95 - i * 0.03)
end
for s = 0, 9 do -- stairs: 8 wide, 1.5 high, 2 deep per step, climbing toward -Z
	block(temple, Vector3.new(8, 1.5 * (s + 1), 2), Vector3.new(0, 0.75 * (s + 1), TZ + 14 + 1 - s * 1.4 + 6), "mossy_stone")
end
block(temple, Vector3.new(6, 6, 6), Vector3.new(0, 18, TZ), "mossy_stone") -- shrine block on top
for _, x in { -6, 6 } do
	torch(Vector3.new(x, 15, TZ + 4))
end
temple.Parent = root

-- Cliffs around the edge (skipping the pool corner, which gets the waterfall).
local cliffs = group("Cliffs")
local function cliffColumn(x, z)
	local base, h = height(x, z), rng:NextInteger(3, 7) * 4 -- stand on the ground cap, not through it
	block(cliffs, Vector3.new(4, h, 4), Vector3.new(x, base + h / 2, z), "mossy_stone")
	block(cliffs, Vector3.new(4, 1, 4), Vector3.new(x, base + h + 0.5, z), "grass") -- grass-block hill top
end
for x = X0 + 2, X1 - 2, 4 do
	cliffColumn(x, Z0 + 2)
	cliffColumn(x, Z1 - 2)
end
for z = Z0 + 6, Z1 - 6, 4 do
	cliffColumn(X0 + 2, z)
	cliffColumn(X1 - 2, z)
end
cliffs.Parent = root

-- Waterfall into the pool: a tall translucent sheet off the back cliff, plus a lighter splash strip.
local falls = group("Waterfall")
local sheet = block(falls, Vector3.new(8, 28, 1), Vector3.new(-48, 14, Z0 + 4.5), "water", 1, false)
sheet.Transparency, sheet.CastShadow = 0.2, false
local splash = block(falls, Vector3.new(10, 0.4, 3), Vector3.new(-48, -0.1, Z0 + 6.5), "water", 1, false)
splash.Color, splash.Transparency = Color3.new(1, 1, 1), 0.3
block(falls, Vector3.new(16, 32, 4), Vector3.new(-48, 16, Z0 + 2), "mossy_stone") -- cliff behind the falls
falls.Parent = root

local function free(x, z, margin)
	return not inArena(x, z)
		and not (math.abs(x) <= 40 and z <= 0 and z >= -44)
		and not (math.abs(x) <= 14 and z > -6 and z <= 28)
		and not inTemple(x, z)
		and not inPool(x, z)
		and x > X0 + margin and x < X1 - margin and z > Z0 + margin and z < Z1 - margin
end

local function jungleTree(pos: Vector3)
	local m = group("JungleTree")
	local h = rng:NextInteger(5, 8)
	for i = 0, h - 1 do
		block(m, Vector3.new(2, 2, 2), pos + Vector3.new(0, 1 + i * 2, 0), "bark")
	end
	local top = pos + Vector3.new(0, h * 2, 0)
	for layer = 0, 1 do -- two wide, flat canopy layers
		local r = 3 - layer
		for dx = -r, r do
			for dz = -r, r do
				if dx * dx + dz * dz <= r * r + 1 and rng:NextNumber() < 0.9 then
					block(m, Vector3.new(2, 2, 2), top + Vector3.new(dx * 2, 1 + layer * 2, dz * 2), "leaves")
				end
			end
		end
	end
	for _ = 1, 4 do -- hanging vines
		local vx, vz = rng:NextInteger(-3, 3) * 2, rng:NextInteger(-3, 3) * 2
		for v = 1, rng:NextInteger(1, 3) do
			block(m, Vector3.new(1, 2, 1), top + Vector3.new(vx, 1 - v * 2, vz), "leaves", nil, false)
		end
	end
	m.Parent = root
end

local function palm(pos: Vector3)
	local m = group("Palm")
	local lean = Vector3.new(rng:NextInteger(-1, 1), 0, rng:NextInteger(-1, 1))
	local p = pos
	for i = 0, 6 do
		p = pos + Vector3.new(0, 1 + i * 2, 0) + lean * math.floor(i / 2)
		block(m, Vector3.new(2, 2, 2), p, "bark", 1) -- tints must stay <= 1: Color3 is stored as bytes and wraps
	end
	local crown = p + Vector3.new(0, 2, 0)
	block(m, Vector3.new(2, 2, 2), crown, "leaves")
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		for s = 1, 3 do -- fronds droop as they go out
			block(m, Vector3.new(2, 1, 2), crown + d * (s * 2) + Vector3.new(0, -math.max(0, s - 1), 0), "leaves", nil, false)
		end
	end
	m.Parent = root
end

local function bush(pos: Vector3)
	local m = group("Bush")
	for _ = 1, rng:NextInteger(2, 4) do
		local s = rng:NextInteger(1, 2) * 1.5
		block(m, Vector3.new(s, s, s), pos + Vector3.new(rng:NextInteger(-1, 1), s / 2, rng:NextInteger(-1, 1)), "leaves", nil, false)
	end
	m.Parent = root
end

local function rock(pos: Vector3)
	local m = group("Rock")
	for _ = 1, rng:NextInteger(2, 3) do
		local s = rng:NextInteger(1, 3)
		block(m, Vector3.new(s, s, s), pos + Vector3.new(rng:NextInteger(-1, 1), s / 2, rng:NextInteger(-1, 1)), "mossy_stone")
	end
	m.Parent = root
end

local function scatter(count: number, margin: number, snap: number, fn)
	local placed, tries = 0, 0
	while placed < count and tries < count * 50 do
		tries += 1
		local x, z = rng:NextInteger(X0, X1), rng:NextInteger(Z0, Z1)
		if free(x, z, margin) then
			local sx, sz = x - x % snap, z - z % snap
			local cx, cz = math.floor(sx / 4) * 4 + 2, math.floor(sz / 4) * 4 + 2 -- centre of the floor cell
			fn(Vector3.new(sx, height(cx, cz), sz))
			placed += 1
			if placed % 5 == 0 then
				task.wait()
			end
		end
	end
end
scatter(16, 10, 2, jungleTree)
scatter(10, 8, 2, palm)
scatter(40, 5, 1, bush)
scatter(20, 5, 1, rock)

-- Baseplate becomes far-off grass just under the tiles.
local bp = workspace:FindFirstChild("Baseplate")
if bp then
	bp.Position = Vector3.new(0, -8.25, 0)
	bp.Material, bp.MaterialVariant, bp.Color = TEX.grass[1], "Voxel_grass", Color3.new(0.9, 0.9, 0.9)
	for _, t in bp:GetChildren() do
		if t:IsA("Texture") then
			t.Transparency = 1
		end
	end
end

local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	spawn.Material, spawn.MaterialVariant, spawn.Color = TEX.mossy_stone[1], "Voxel_mossy_stone", Color3.new(1, 1, 1)
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then
			d.Transparency = 1
		end
	end
end

-- Lighting: bright, cheerful and soft (kid-friendly): high ambient so shade never goes dark, light haze, no blur.
Lighting.ClockTime, Lighting.Brightness = 13, 2.4
Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(110, 114, 124), Color3.fromRGB(160, 166, 176)
Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0.6, 0.05
Lighting.GlobalShadows, Lighting.ShadowSoftness = true, 0.2
local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then
	dof.Enabled = false
end
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if atm then
	atm.Density, atm.Offset, atm.Haze, atm.Glare = 0.22, 0.2, 0.6, 0
	atm.Color, atm.Decay = Color3.fromRGB(200, 226, 255), Color3.fromRGB(150, 190, 230)
end
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.4, 18, 1.6
end
local cc = Lighting:FindFirstChild("VoxelGrade") or Instance.new("ColorCorrectionEffect")
cc.Name, cc.Brightness, cc.Saturation, cc.Contrast, cc.TintColor = "VoxelGrade", 0, 0.2, 0.02, Color3.fromRGB(255, 252, 245)
cc.Parent = Lighting

local n = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("VoxelArena: %d parts"):format(n)
