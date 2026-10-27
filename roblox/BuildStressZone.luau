-- BuildStressZone.luau: run in the Command Bar (Edit mode). Safe to re-run: it rebuilds workspace.StressZone.
-- A bare arena 400 studs east of the camp for goblin load tests: one flat floor part, low walls, no
-- decor, so the numbers measure goblins and nothing else. GoblinAI spawns test goblins here (Studio only) when
-- the GoblinStressHUD buttons ask for them. Undo: delete workspace.StressZone.
local CENTER, SIZE = Vector3.new(400, 0, 0), 120

local old = workspace:FindFirstChild("StressZone")
if old then
	old:Destroy()
end
local zone = Instance.new("Model")
zone.Name = "StressZone"

local function part(size: Vector3, pos: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Anchored, p.CanTouch = true, false
	p.Size, p.Position, p.Color, p.Material = size, CENTER + pos, color, Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = zone
	return p
end

part(Vector3.new(SIZE, 1, SIZE), Vector3.new(0, -0.5, 0), Color3.fromRGB(150, 156, 146)) -- one part, no tiles
for _, w in { { 0, SIZE / 2 }, { 0, -SIZE / 2 }, { SIZE / 2, 0 }, { -SIZE / 2, 0 } } do
	local along = w[1] == 0
	part(Vector3.new(along and SIZE or 2, 4, along and 2 or SIZE), Vector3.new(w[1], 2, w[2]), Color3.fromRGB(110, 90, 70))
end
local spawn = part(Vector3.new(8, 1, 8), Vector3.new(0, 0.5, SIZE / 2 - 8), Color3.fromRGB(90, 140, 200))
spawn.Name = "TesterPad" -- the HUD's "Zone" button drops the player here

zone:SetAttribute("Center", CENTER)
zone:SetAttribute("Size", SIZE)
zone.Parent = workspace
return "StressZone built at " .. tostring(CENTER)
