-- GoblinVFXClient (LocalScript, StarterPlayer.StarterPlayerScripts)
-- Gives every model tagged "Goblin" its client-side VFX and removes them when the tag or model goes away.
-- Preview: set the attribute GoblinVFXPreview = true on Workspace to cycle every effect on every goblin.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Goblin = ReplicatedStorage:WaitForChild("Goblin")
local Config = require(Goblin:WaitForChild("GoblinConfig"))
local GoblinVFX = require(Goblin:WaitForChild("GoblinVFX"))

local function added(model: Instance)
	if model:IsA("Model") then
		GoblinVFX.attach(model)
	end
end

CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(added)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(function(model)
	GoblinVFX.detach(model)
end)
for _, model in CollectionService:GetTagged(Config.Tag) do
	added(model)
end

task.spawn(function() -- server-confirmed sword hits (GoblinAI creates the remote; absent in showcase mode)
	Goblin:WaitForChild("Impact").OnClientEvent:Connect(GoblinVFX.impact)
end)

local PREVIEW = { -- event, seconds to wait after it
	{ "Footstep", 0.6 }, { "LungeStart", 1 }, { "Telegraph", 1.2 }, { "Swing", 0.8 }, { "SwingHeavy", 0.8 },
	{ "Impact", 1 }, { "Hit", 1 }, { "Alert", 1 }, { "StunStars", 2 }, { "BodyFall", 1 }, { "Dissolve", 2.5 },
}

task.spawn(function()
	while true do
		if Workspace:GetAttribute("GoblinVFXPreview") then
			for _, step in PREVIEW do
				for _, model in CollectionService:GetTagged(Config.Tag) do
					local ev = step[1]
					if ev == "Swing" or ev == "SwingHeavy" then
						GoblinVFX.previewSwing(model, ev == "SwingHeavy")
					elseif ev == "Hit" then
						GoblinVFX.impact(model:GetPivot().Position + model:GetPivot().LookVector * 3 + Vector3.new(0, 1, 0))
					else
						GoblinVFX.fire(model, ev)
					end
					if ev == "StunStars" then
						task.delay(step[2], function()
							local h = GoblinVFX.attach(model)
							h.stars.Enabled = false
						end)
					elseif ev == "Dissolve" then
						task.delay(step[2], function() -- bring the goblin back for the next loop
							GoblinVFX.detach(model)
							for _, d in model:GetDescendants() do
								if d:IsA("BasePart") then
									d.LocalTransparencyModifier = 0
								end
							end
							GoblinVFX.attach(model)
						end)
					end
				end
				task.wait(step[2])
			end
		else
			task.wait(1)
		end
	end
end)
