-- GoblinShowcase (Script, ServerScriptService)
-- Play-mode gallery: clones workspace.Goblin into a 7x3 grid, each copy repeats one animation (VFX come from
-- GoblinVFXClient via the "Goblin" tag) under a name label. Disable or delete this script to turn it off.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Goblin"):WaitForChild("GoblinConfig"))
local AnimData = require(ReplicatedStorage.Goblin:WaitForChild("GoblinAnimData"))

local ROWS = {
	{ "Idle", "CombatIdle", "Alert", "Walk", "Run", "TurnLeft", "TurnRight" },
	{ "Attack1", "Attack2", "Attack3", "HeavyAttack", "LungeAttack", "Stun", "Knockback" },
	{ "HitFront", "HitLeft", "HitRight", "Death", "Jump", "Fall", "Land" },
}
local SPACING, PAUSE = 9, 1.2

local template = Workspace:WaitForChild("Goblin")
local base = template:GetPivot()
template.Parent = nil -- runtime only; the place file keeps the original

local function spawnGoblin(name: string, cf: CFrame): (Model, AnimationTrack)
	local g = template:Clone()
	g.Name = "Goblin_" .. name
	g:PivotTo(cf)
	g.HumanoidRootPart.Anchored = true -- root motion clips stay in their slot
	g:FindFirstChildWhichIsA("Humanoid").DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset = UDim2.fromScale(7, 1.2), Vector3.new(0, 5, 0) -- in studs, shrinks with distance
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Text, label.TextScaled, label.Font = name, true, Enum.Font.GothamBold
	label.TextColor3, label.TextStrokeTransparency = Color3.new(1, 1, 1), 0.3
	label.Parent = gui
	gui.Parent = g.HumanoidRootPart

	g.Parent = Workspace
	local anim = Instance.new("Animation")
	anim.AnimationId = Config.Animations[name]
	return g, g:FindFirstChildWhichIsA("Animator", true):LoadAnimation(anim)
end

for r, row in ROWS do
	for c, name in row do
		local cf = base * CFrame.new((c - 4) * SPACING, 0, (r - 1) * SPACING)
		task.spawn(function()
			local g, track = spawnGoblin(name, cf)
			if AnimData[name].looped then
				track:Play()
				return
			end
			while true do
				track:Play()
				if name == "Death" then -- hold the last frame while the client dissolve (1.5 s + fade) runs
					task.wait(AnimData.Death.length - 0.05)
					track:AdjustSpeed(0)
					task.wait(Config.VFX.DeathFadeTime + PAUSE)
					g:Destroy() -- the dissolve leaves it invisible on the client: swap in a fresh copy
					g, track = spawnGoblin(name, cf)
				else
					track.Stopped:Wait()
				end
				task.wait(PAUSE)
			end
		end)
	end
end
