-- GoblinStressHUD (LocalScript, StarterPlayer.StarterPlayerScripts) - Studio-only goblin load-test panel.
-- Buttons ask GoblinAI for more or fewer Humanoid goblins, or GoblinHorde for more or fewer horde goblins ("H"), in
-- workspace.StressZone, and move you between the zone and the camp. The panel shows client FPS next to the server
-- numbers both scripts publish (Goblin.Stress and Goblin.Horde attributes).
-- In Studio the client and server share one machine, so both sides' costs show up in both FPS numbers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
	return
end
local stress = ReplicatedStorage:WaitForChild("Goblin"):WaitForChild("Stress")
local horde = ReplicatedStorage.Goblin:WaitForChild("Horde")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "GoblinStressHUD", false
local panel = Instance.new("Frame")
panel.Size, panel.Position = UDim2.fromOffset(230, 304), UDim2.new(0, 12, 0.5, -152)
panel.BackgroundColor3, panel.BackgroundTransparency = Color3.new(0, 0, 0), 0.35
panel.Parent = gui
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8)
pad.Parent = panel

local label = Instance.new("TextLabel")
label.Size, label.BackgroundTransparency = UDim2.new(1, 0, 0, 186), 1
label.Font, label.TextSize, label.TextColor3 = Enum.Font.Code, 14, Color3.new(1, 1, 1)
label.TextXAlignment, label.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
label.Parent = panel

local buttons = Instance.new("Frame")
buttons.Size, buttons.Position, buttons.BackgroundTransparency = UDim2.new(1, 0, 0, 96), UDim2.fromOffset(0, 192), 1
buttons.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize, grid.CellPadding = UDim2.new(1 / 3, -4, 0, 28), UDim2.fromOffset(4, 4)
grid.Parent = buttons

local function count(): number
	return stress:GetAttribute("Count") or 0
end
local function goTo(part: BasePart?)
	local char = player.Character
	if part and char then
		char:PivotTo(part.CFrame + Vector3.new(0, 4, 0))
	end
end
local function button(text: string, onClick: () -> ())
	local b = Instance.new("TextButton")
	b.Text, b.Font, b.TextSize = text, Enum.Font.GothamBold, 14
	b.BackgroundColor3, b.TextColor3 = Color3.fromRGB(60, 60, 60), Color3.new(1, 1, 1)
	b.Parent = buttons
	b.Activated:Connect(onClick)
end
button("+10", function()
	stress:FireServer(count() + 10)
end)
button("+50", function()
	stress:FireServer(count() + 50)
end)
button("-10", function()
	stress:FireServer(math.max(0, count() - 10))
end)
button("Clear", function()
	stress:FireServer(0)
end)
button("H +100", function()
	horde:FireServer((horde:GetAttribute("Target") or 0) + 100)
end)
button("H -100", function()
	horde:FireServer(math.max(0, (horde:GetAttribute("Target") or 0) - 100))
end)
button("H Clear", function()
	horde:FireServer(0)
end)
button("Zone", function()
	local zone = Workspace:FindFirstChild("StressZone")
	goTo(zone and zone:FindFirstChild("TesterPad"))
end)
button("Camp", function()
	goTo(Workspace:FindFirstChildOfClass("SpawnLocation"))
end)
gui.Parent = player:WaitForChild("PlayerGui")

local frames, t0 = 0, os.clock()
RunService.RenderStepped:Connect(function()
	frames += 1
	local dt = os.clock() - t0
	if dt < 1 then
		return
	end
	local fps = math.round(frames / dt)
	frames, t0 = 0, os.clock()
	player:SetAttribute("ClientFPS", fps) -- for scripted benchmarks
	local a, h = stress:GetAttributes(), horde:GetAttributes()
	label.Text = ("Goblins     %d\nHorde       %d / %d\nHorde sim   %.2f ms  %d KB/s\nClient FPS  %d\nServer FPS  %d\nHeartbeat   %.1f ms\nPhysics     %.1f ms\nMemory      %d MB\nPaths/s     %d\nRays/s      %d"):format(
		a.Count or 0,
		h.Count or 0,
		h.Target or 0,
		h.SimMs or 0,
		h.KBps or 0,
		fps,
		a.ServerFPS or 0,
		a.HeartbeatMs or 0,
		a.PhysicsMs or 0,
		a.MemoryMb or 0,
		a.PathsPerSec or 0,
		a.RaysPerSec or 0
	)
end)
