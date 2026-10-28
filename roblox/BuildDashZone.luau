-- BuildDashZone.luau: run in the Command Bar (Edit mode). Safe to re-run: it rebuilds workspace.DashZone.
-- A dash practice field 400 studs south of the camp (GAME-44): standing in it you can dash with no cooldown, holding a
-- lent sword so the SwordDash animations play (GoblinHorde's Dash block, PlayerSword). Studded 16-stud checker tiles
-- (one tile = one dash), with things to dash at: pillars, a thin wall (the dash stops before it), a raised ledge (it
-- stops at the edge), and the Map1 temple gate when Map1Kit has it (dash through the arch). The DASH pad by the spawn
-- drops you on DashSpawn; the BACK pad here returns you. Undo: delete workspace.DashZone.
local CENTER, SIZE, TILE = Vector3.new(0, 0, -400), 160, 16

local old = workspace:FindFirstChild("DashZone")
if old then
	old:Destroy()
end
local zone = Instance.new("Model")
zone.Name = "DashZone"

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local function part(name: string, size: Vector3, pos: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanTouch = name, true, false
	p.Size, p.Position, p.Color, p.Material = size, CENTER + pos, color, Enum.Material.Plastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Studs, Enum.SurfaceType.Smooth
	p.Parent = zone
	return p
end

-- the floor: checker tiles a dash long, top at y = 0.05 (just over the lobby Baseplate)
local n = SIZE // TILE
for i = 0, n - 1 do
	for j = 0, n - 1 do
		local x, z = -SIZE / 2 + TILE * (i + 0.5), -SIZE / 2 + TILE * (j + 0.5)
		part("Floor", Vector3.new(TILE, 1, TILE), Vector3.new(x, -0.45, z), if (i + j) % 2 == 0 then rgb(98, 176, 70) else rgb(80, 150, 66))
	end
end
for _, w in { { 0, SIZE / 2 }, { 0, -SIZE / 2 }, { SIZE / 2, 0 }, { -SIZE / 2, 0 } } do -- low border
	local along = w[1] == 0
	part("Border", Vector3.new(along and SIZE + 2 or 2, 4, along and 2 or SIZE + 2), Vector3.new(w[1], 2, w[2]), rgb(150, 154, 140))
end
-- things to dash at
for k = -2, 1 do
	part("Pillar", Vector3.new(6, 12, 6), Vector3.new(k * 24 + 12, 6, -24), rgb(150, 154, 140))
end
part("ThinWall", Vector3.new(20, 8, 0.5), Vector3.new(-40, 4, 24), rgb(176, 170, 152))
part("Ledge", Vector3.new(32, 4, 32), Vector3.new(40, 2, 32), rgb(136, 142, 128))
part("LedgeStep", Vector3.new(8, 2, 32), Vector3.new(20, 1, 32), rgb(150, 154, 140))
local kit = game:GetService("ServerStorage"):FindFirstChild("Map1Kit")
local gate = kit and kit:FindFirstChild("Prop_TempleGate")
if gate then
	gate = gate:Clone()
	gate:PivotTo(CFrame.new(CENTER + Vector3.new(0, 0.05, -56)))
	gate.Parent = zone
end
local spawn = part("DashSpawn", Vector3.new(8, 0.4, 8), Vector3.new(0, 0.25, SIZE / 2 - 12), rgb(90, 200, 235))
spawn.Material = Enum.Material.Neon
local sign = part("Sign", Vector3.new(1, 6, 1), Vector3.new(-10, 3, SIZE / 2 - 12), rgb(110, 68, 40))
local gui = Instance.new("BillboardGui")
gui.Size, gui.StudsOffset, gui.AlwaysOnTop = UDim2.fromOffset(260, 60), Vector3.new(0, 5, 0), true
local label = Instance.new("TextLabel")
label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
label.Text, label.FontFace, label.TextScaled = "DASH FIELD\nQ / B / tap: no cooldown", Font.fromEnum(Enum.Font.FredokaOne), true
label.TextColor3, label.TextStrokeTransparency = Color3.new(1, 1, 1), 0
label.Parent = gui
gui.Parent = sign

zone:SetAttribute("Center", CENTER)
zone:SetAttribute("Size", SIZE)
zone:SetAttribute("Spawn", spawn.Position)
zone.Parent = workspace
return "DashZone built at " .. tostring(CENTER) .. (if gate then " (with the temple gate)" else "")
