-- BuildSwordFXZone.luau: run in the Command Bar (Edit mode). Safe to re-run: it rebuilds workspace.SwordFXZone.
-- A viewing strip 400 studs west of the camp: five pedestals Lv1..Lv5 that GoblinHordeClient makes swing the sword at
-- that level, over and over, while you stand nearby (GAME-33). The SWORD FX pad by the spawn (GoblinHorde) and the
-- Studio-only GoblinStressHUD "FX" button drop you on ViewPad; a BACK pad beside it returns you to the spawn.
-- Undo: delete workspace.SwordFXZone.
local CENTER, GAP = Vector3.new(-400, 0, 0), 26
local NAMES = { "Wood", "Gold", "Double", "Energy", "Legendary" }

local old = workspace:FindFirstChild("SwordFXZone")
if old then
	old:Destroy()
end
local zone = Instance.new("Model")
zone.Name = "SwordFXZone"

local function part(name: string, size: Vector3, pos: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanTouch = name, true, false
	p.Size, p.Position, p.Color, p.Material = size, CENTER + pos, color, Enum.Material.Plastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Studs, Enum.SurfaceType.Smooth
	p.Parent = zone
	return p
end

part("Floor", Vector3.new(GAP * 5 + 20, 1, 70), Vector3.new(0, -0.45, 0), Color3.fromRGB(124, 92, 62)) -- Map 1 dirt, just above the Baseplate
for n = 1, 5 do
	local x = (n - 3) * GAP
	part("Pedestal" .. n, Vector3.new(4, 1, 4), Vector3.new(x, 0.5, 0), Color3.fromRGB(158, 150, 132))
	-- The swing centre: the client draws each slash around this part, as it would around a player's root.
	local root = part("Lv" .. n, Vector3.new(1, 2, 1), Vector3.new(x, 3, 0), Color3.new(1, 1, 1))
	root.Transparency, root.CanCollide, root.CanQuery = 1, false, false
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset, gui.AlwaysOnTop = UDim2.fromOffset(160, 40), Vector3.new(0, 4, 0), true
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Text, label.Font, label.TextSize = "Lv " .. n .. "  " .. NAMES[n], Enum.Font.GothamBold, 20
	label.TextColor3, label.TextStrokeTransparency = Color3.new(1, 1, 1), 0.3
	label.Parent = gui
	gui.Parent = root
end
part("ViewPad", Vector3.new(8, 1, 8), Vector3.new(0, 0.5, 26), Color3.fromRGB(90, 140, 200))

zone.Parent = workspace
return "SwordFXZone built at " .. tostring(CENTER)
