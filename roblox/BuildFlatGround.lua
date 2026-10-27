-- BuildFlatGround.lua: run in the Command Bar (Edit mode). Safe to re-run: it rebuilds workspace.FlatGround.
-- Goblin war camp in the chunky voxel "soft" style of goblin/scripts/11_lookdev_camp.py (STYLE=soft; same layout
-- and tints; check changes there first): 4-stud grass tiles, a trampled-mud clearing ringed by a banded-stake
-- palisade with rails and bone tips, a skull gate with tattered banners, mossy stepped boulders, a campfire, and
-- soft bright daylight. The ground stays flat (every tile top at y = 0, where the goblin stands).
-- Pixel textures (goblin/textures/voxel_soft, made by PALETTE=soft 10_voxel_textures.py) go on MaterialService.Camp_* variants.
-- If an image is unavailable the builder falls back to built-in materials
-- tinted to each texture's average color. Re-run once they load to switch to the pixel look.
-- Undo: delete workspace.FlatGround (the Baseplate is only lowered under the tiles).
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local rng = Random.new(21)

local TEX = { -- image, base material (physics + fallback look), fallback color (texture average, tuned for how
	-- Roblox renders the built-in material)
	grass = { "rbxassetid://126261012928705", Enum.Material.Grass, Color3.fromRGB(117, 178, 77) },
	dirt = { "rbxassetid://133288330441912", Enum.Material.Ground, Color3.fromRGB(170, 132, 96) },
	bark = { "rbxassetid://121757519712785", Enum.Material.Wood, Color3.fromRGB(122, 94, 70) },
	stone = { "rbxassetid://92748181928704", Enum.Material.Slate, Color3.fromRGB(146, 155, 134) },
	bone = { "rbxassetid://96301841810258", Enum.Material.Limestone, Color3.fromRGB(227, 216, 191) },
	cloth = { "rbxassetid://121513515493422", Enum.Material.Fabric, Color3.fromRGB(195, 67, 56) },
}
local probes, loaded = {}, 0
for name, t in TEX do
	local v = MaterialService:FindFirstChild("Camp_" .. name) or Instance.new("MaterialVariant")
	v.Name, v.BaseMaterial, v.ColorMap, v.StudsPerTile = "Camp_" .. name, t[2], t[1], 4
	v.Parent = MaterialService
	-- An ImageLabel requests texture content; a bare asset-id can falsely report Failure.
	local probe = Instance.new("ImageLabel")
	probe.Image = t[1]
	table.insert(probes, probe)
end
game:GetService("ContentProvider"):PreloadAsync(probes, function(_, st)
	loaded += if st == Enum.AssetFetchStatus.Success then 1 else 0
end)
local TEXTURED = loaded == #probes
for _, probe in probes do
	probe:Destroy()
end

local BLACK, IRON = Color3.fromRGB(30, 24, 22), Color3.fromRGB(54, 52, 52)
local TUFT = { Color3.fromRGB(70, 128, 54), Color3.fromRGB(70, 128, 54), Color3.fromRGB(110, 164, 70) }
local FIRE = { Color3.fromRGB(255, 120, 30), Color3.fromRGB(255, 190, 50), Color3.fromRGB(255, 240, 140) }
local X0, X1, Z0, Z1 = -100, 100, -100, 60
local CX, CZ, RX, RZ = 0, -21, 36, 17 -- clearing oval around the showcase grid (x -27..27, z -12..-30)

local old = workspace:FindFirstChild("FlatGround")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "FlatGround"
root.Parent = workspace

-- Textured blocks get a gray tint k (Part.Color multiplies the texture); the fallback bakes the color in.
local function skin(p: BasePart, tex: string, k: number)
	local t = TEX[tex]
	p.Material = t[2]
	p.MaterialVariant = if TEXTURED then "Camp_" .. tex else ""
	p.Color = if TEXTURED then Color3.new(k, k, k) else t[3]:Lerp(Color3.new(0, 0, 0), 1 - k)
end
local function part(parent, size: Vector3, cf: CFrame, look: string | Color3, k: number?, solid: boolean?)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch = true, solid or false, false
	p.CastShadow = size.Y > 1.1 -- flat tiles skip shadows; everything standing up casts one
	p.Size, p.CFrame = size, cf
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if typeof(look) == "string" then
		skin(p, look, k or 1)
	else
		p.Material, p.Color = Enum.Material.SmoothPlastic, look
	end
	p.Parent = parent
	return p
end
local function group(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	return m
end

local function oval(x: number, z: number): number -- < 1 inside the clearing
	return ((x - CX) / RX) ^ 2 + ((z - CZ) / RZ) ^ 2
end
local function onMud(x: number, z: number): boolean
	local d = oval(x, z)
	if d <= 0.82 then
		return true
	elseif d <= 1.05 then
		return rng:NextNumber() < 0.5 -- ragged rim
	end
	return z <= 6 and z > -10 and math.abs(x) <= 4 -- path from the spawn
end

-- 3-5 thin blades, walk-through, no shadows (there are hundreds).
local function tuft(parent, x: number, z: number)
	for _ = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(0.6, 1.8)
		local cf = CFrame.new(x + rng:NextNumber(-0.6, 0.6), h / 2, z + rng:NextNumber(-0.6, 0.6))
			* CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2))
		part(parent, Vector3.new(0.3, h, 0.3), cf, TUFT[rng:NextInteger(1, #TUFT)]).CastShadow = false
	end
end

-- Ground tiles, one Model per column so each Parent write stays small.
for x = X0, X1 - 4, 4 do
	local col = group("Tiles")
	for z = Z0, Z1 - 4, 4 do
		local cx, cz = x + 2, z + 2
		local cf = CFrame.new(cx, -0.5, cz)
		if onMud(cx, cz) then
			part(col, Vector3.new(4, 1, 4), cf, "dirt", if rng:NextNumber() < 0.22 then 0.8 else rng:NextNumber(0.9, 1), true)
		else
			local t = math.clamp(math.noise(cx / 26, cz / 26, 0.5) * 0.6 + 0.6 + rng:NextNumber(-0.1, 0.1), 0, 1)
			part(col, Vector3.new(4, 1, 4), cf, "grass", 0.85 + 0.15 * t, true)
			if oval(cx, cz) > 1.15 and math.abs(cx) + math.abs(cz - 10) > 9 and rng:NextNumber() < 0.3 then
				tuft(col, cx + rng:NextNumber(-1.5, 1.5), cz + rng:NextNumber(-1.5, 1.5))
			end
		end
	end
	col.Parent = root
	task.wait()
end

-- Chunky stake leaning outward: banded post and (unless a gate post) a stepped bone tip. Returns its top.
local function stake(parent, base: Vector3, h: number, out: Vector3, w: number?, tips: boolean?)
	w = w or 1.8
	local cf = CFrame.new(base) * CFrame.fromAxisAngle(Vector3.yAxis:Cross(out).Unit, math.rad(rng:NextNumber(2, 7)))
	part(parent, Vector3.new(w, h, w), cf * CFrame.new(0, h / 2, 0), "bark", rng:NextNumber(0.8, 1), true)
	part(parent, Vector3.new(w + 0.2, 0.3, w + 0.2), cf * CFrame.new(0, h * 0.72, 0), IRON).Material = Enum.Material.Metal
	if tips ~= false then
		part(parent, Vector3.new(w * 0.75, 0.7, w * 0.75), cf * CFrame.new(0, h + 0.35, 0), "bone", 0.78)
		part(parent, Vector3.new(w * 0.5, 0.6, w * 0.5), cf * CFrame.new(0, h + 1, 0), "bone", 0.78)
		part(parent, Vector3.new(w * 0.25, 0.5, w * 0.25), cf * CFrame.new(0, h + 1.55, 0), "bone", 0.78)
	end
	return cf * CFrame.new(0, h, 0)
end

-- Blocky skull looking along cf's -Z: head, two eye sockets, nose, jaw.
local function skull(parent, cf: CFrame)
	part(parent, Vector3.new(1.4, 1.2, 1.3), cf * CFrame.new(0, 0.6, 0), "bone", 0.82)
	part(parent, Vector3.new(1, 0.4, 1), cf * CFrame.new(0, -0.1, -0.15), "bone", 0.82)
	for _, x in { -0.35, 0.35 } do
		part(parent, Vector3.new(0.38, 0.38, 0.1), cf * CFrame.new(x, 0.65, -0.66), BLACK)
	end
	part(parent, Vector3.new(0.2, 0.25, 0.1), cf * CFrame.new(0, 0.3, -0.66), BLACK)
end
local FACE_SPAWN = CFrame.Angles(0, math.pi, 0)

-- Tattered cloth hanging from y = top: main sheet + ragged strips of uneven length.
local function banner(parent, x: number, top: number, z: number, w: number, h: number)
	part(parent, Vector3.new(w, h, 0.2), CFrame.new(x, top - h / 2, z), "cloth", 0.8)
	for i = 0, 3 do
		local l = rng:NextNumber(0.6, 2.2)
		part(parent, Vector3.new(w / 4, l, 0.2), CFrame.new(x - w / 2 + w / 4 * (i + 0.5), top - h - l / 2, z), "cloth", rng:NextNumber(0.65, 0.8))
	end
end

-- Palisade just outside the clearing, open toward the spawn path, rails between neighbouring stakes.
local fence = group("Palisade")
local ring = {}
for i = 0, 95 do
	local a = i / 96 * math.pi * 2
	local x, z = CX + math.sin(a) * (RX + 3), CZ + math.cos(a) * (RZ + 3)
	if z > CZ and math.abs(x) < 9 then -- the gate
		ring[i + 1] = false
	else
		stake(fence, Vector3.new(x, 0, z), rng:NextNumber(4, 5.5), Vector3.new(math.sin(a), 0, math.cos(a)))
		ring[i + 1] = Vector3.new(x, 2.4, z)
	end
end
for i, p in ring do
	local q = ring[i % #ring + 1]
	if p and q then
		part(fence, Vector3.new(0.6, 0.7, (q - p).Magnitude + 0.4), CFrame.lookAt((p + q) / 2, q), "bark", 0.8)
	end
end
fence.Parent = root

-- Gate: two thick posts topped with skulls, banners on their fronts, a crossbeam with hanging skulls.
local gate = group("Gate")
local gz = CZ + RZ + 3
for _, x in { -9, 9 } do
	local top = stake(gate, Vector3.new(x, 0, gz), 8, Vector3.zAxis, 2.6, false)
	skull(gate, CFrame.new(top.Position + Vector3.new(0, 0.2, 0)) * FACE_SPAWN)
	banner(gate, x, 7.4, gz + 1.45, 2.2, 5)
end
part(gate, Vector3.new(20, 1, 1), CFrame.new(0, 6.8, gz), "bark", 0.85)
for _, x in { -4.5, 0, 4.5 } do
	part(gate, Vector3.new(0.15, 1.4, 0.15), CFrame.new(x, 5.6, gz), IRON).Material = Enum.Material.Metal
	skull(gate, CFrame.new(x, 3.7, gz) * FACE_SPAWN)
end
gate.Parent = root

-- War banners on poles inside the gate.
for _, bx in { -16, 16 } do
	local m = group("Banner")
	part(m, Vector3.new(0.6, 9, 0.6), CFrame.new(bx, 4.5, -2), "bark", 1, true)
	banner(m, bx + 1.6, 8.6, -2, 2.6, 3.5)
	m.Parent = root
end

-- Bone piles near the fence, inside the clearing but away from the goblins.
local function bones(pos: Vector3)
	local m = group("Bones")
	for _ = 1, rng:NextInteger(3, 5) do
		local cf = CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1), 0.2, rng:NextNumber(-1, 1))) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		part(m, Vector3.new(0.35, 0.35, 1.8), cf, "bone", 0.8)
		part(m, Vector3.new(0.6, 0.5, 0.5), cf * CFrame.new(0, 0, 0.9), "bone", 0.8)
		part(m, Vector3.new(0.6, 0.5, 0.5), cf * CFrame.new(0, 0, -0.9), "bone", 0.8)
	end
	if rng:NextNumber() < 0.5 then
		skull(m, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	end
	m.Parent = root
end
for _, p in { Vector3.new(-33, 0, -14), Vector3.new(33, 0, -28), Vector3.new(-30, 0, -32), Vector3.new(31, 0, -12), Vector3.new(-12, 0, -36), Vector3.new(14, 0, -36) } do
	bones(p)
end

-- Campfire behind the goblins: stone ring, crossed logs, stacked glowing flame blocks, warm amber light.
local fire = group("Campfire")
local FP = Vector3.new(0, 0, -36)
for i = 0, 7 do
	local a = i / 8 * math.pi * 2
	part(fire, Vector3.new(0.9, 0.7, 0.9), CFrame.new(FP + Vector3.new(math.sin(a) * 1.9, 0.35, math.cos(a) * 1.9)), "stone", 0.9)
end
for _, a in { 0.4, -0.5 } do
	part(fire, Vector3.new(3.4, 0.6, 0.6), CFrame.new(FP + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, a, 0), "bark", 0.7)
end
local flame
for i, c in FIRE do
	flame = part(fire, Vector3.new(1.6 - i * 0.4, 0.9, 1.6 - i * 0.4), CFrame.new(FP + Vector3.new(0, 0.6 + i * 0.7, 0)) * CFrame.Angles(0, i * 0.5, 0), c)
	flame.Material, flame.CastShadow = Enum.Material.Neon, false
end
local light = Instance.new("PointLight")
light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 140, 50), 20, 1.4, false
light.Parent = flame
fire.Parent = root

-- Mossy stepped boulders outside the fence (where the tents used to be).
for _, pos in { Vector3.new(-50, 0, -16), Vector3.new(50, 0, -26), Vector3.new(-26, 0, -48), Vector3.new(28, 0, -48) } do
	local m = group("Boulder")
	for i = 0, 4 do
		local w = 13 - i * 2.5
		for _ = 1, 5 do
			local off = Vector3.new(rng:NextNumber(-2.5, 2.5), 1 + i * 2, rng:NextNumber(-2.5, 2.5))
			part(m, Vector3.new(w * rng:NextNumber(0.5, 0.8), 2, w * rng:NextNumber(0.5, 0.8)), CFrame.new(pos + off), "stone", rng:NextNumber(0.7, 0.95), true)
		end
	end
	m.Parent = root
end

-- Spawn pad: 3x3 stone slabs with grass showing in the seams; the SpawnLocation is the middle one.
local pad = group("SpawnPad")
for _, ix in { -4, 0, 4 } do
	for _, iz in { -4, 0, 4 } do
		if ix ~= 0 or iz ~= 0 then
			part(pad, Vector3.new(3.7, 1, 3.7), CFrame.new(ix, 0.5, 10 + iz), "stone", rng:NextNumber(0.82, 1), true)
		end
	end
end
pad.Parent = root
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	spawn.Size, spawn.CFrame = Vector3.new(3.7, 1, 3.7), CFrame.new(0, 0.5, 10)
	skin(spawn, "stone", 0.9)
	local d = spawn:FindFirstChildOfClass("Decal")
	if d then
		d:Destroy()
	end
end

-- Baseplate: the far-off grass, just under the tiles so their tops don't z-fight with it.
local bp = workspace:FindFirstChild("Baseplate")
if bp then
	bp.Position = Vector3.new(0, -8.2, 0)
	skin(bp, "grass", 0.92)
end

-- Soft bright daylight: gentle shadows, lots of sky fill, light haze, a touch of saturation, no bloom/DoF.
Lighting.ClockTime, Lighting.Brightness, Lighting.ShadowSoftness = 13, 2.6, 0.4
Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(96, 100, 110), Color3.fromRGB(150, 160, 176)
Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0.8, 0.2
local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmo.Density, atmo.Offset, atmo.Haze, atmo.Glare = 0.26, 0.1, 0.9, 0
atmo.Color, atmo.Decay = Color3.fromRGB(206, 220, 238), Color3.fromRGB(150, 178, 214)
atmo.Parent = Lighting
local cc = Lighting:FindFirstChild("VoxelGrade") or Instance.new("ColorCorrectionEffect")
cc.Name, cc.Brightness, cc.Saturation, cc.Contrast = "VoxelGrade", 0.02, 0.06, 0.04
cc.TintColor = Color3.fromRGB(255, 252, 246)
cc.Parent = Lighting
for _, e in Lighting:GetChildren() do
	if e:IsA("BloomEffect") then
		e.Intensity, e.Threshold = 0.3, 1.5
	elseif e:IsA("DepthOfFieldEffect") or e:IsA("SunRaysEffect") then
		e.Enabled = false
	end
end
local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
clouds.Cover, clouds.Density, clouds.Color = 0.5, 0.6, Color3.fromRGB(250, 250, 252)
clouds.Parent = workspace.Terrain

local n = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("FlatGround: %d parts, %s (%d/%d textures loaded)"):format(n, if TEXTURED then "pixel textures" else "fallback materials", loaded, #probes)
