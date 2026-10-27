--!strict
-- Horde game sound effects. Listens to the same remotes the visuals use (GoblinHordeClient, GoblinRunUI) and plays
-- 2D sounds for the local player; ids and mix live in ReplicatedStorage.Goblin.GoblinSounds. A separate script so it
-- never conflicts with work on the visual scripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Goblin")
local Sounds = require(Shared:WaitForChild("GoblinSounds"))
local me = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "GoblinSFX"
folder.Parent = SoundService
local templates: { [string]: Sound } = {}
for name, def in Sounds do
	local s = Instance.new("Sound")
	s.Name, s.SoundId, s.Volume = name, "rbxassetid://" .. def.Id, def.Volume
	s.Parent = folder
	templates[name] = s
end

local lastPlayed: { [string]: number } = {}
-- Plays one copy (PlayLocalSound overlaps freely) unless this sound already played within its cooldown.
local function play(name: string, pitch: number?)
	local def, now = Sounds[name], os.clock()
	if now - (lastPlayed[name] or 0) < def.Cooldown then
		return
	end
	lastPlayed[name] = now
	local range = def.Pitch
	templates[name].PlaybackSpeed = pitch or (range and range[1] + math.random() * (range[2] - range[1])) or 1
	SoundService:PlayLocalSound(templates[name])
	if game:GetService("RunService"):IsStudio() and Shared:GetAttribute("GAME25Active") then
		folder:SetAttribute(name, (folder:GetAttribute(name) or 0) + 1)
	end
end

local function swordLevel(): number
	return tonumber(string.match(me:GetAttribute("RunLoadout") or "", "sword=(%d+)")) or 1
end

Shared:WaitForChild("HordeFx").OnClientEvent:Connect(function(kind: string, ...)
	local args = { ... }
	if kind == "slash" and args[1] == me then
		play("Slash", 0.95 + swordLevel() * 0.04) -- a little brighter with each sword level
	elseif kind == "fire" and args[7] == me then
		play("Fireball")
	end
end)

-- HordeHits only reaches the player who landed them.
Shared:WaitForChild("HordeHits").OnClientEvent:Connect(function()
	play("Hit")
end)

Shared:WaitForChild("HordeDied").OnClientEvent:Connect(function()
	play("GoblinPop")
end)

Shared:WaitForChild("HordeSwing").OnClientEvent:Connect(function()
	play("GoblinSwing") -- the wind-up telegraph: hear it, step away
end)

-- Gem pickups climb in pitch while they keep coming, then reset after a short pause.
local combo, comboAt = 0, 0
Shared:WaitForChild("HordeGems").OnClientEvent:Connect(function(player: Player)
	if player ~= me then
		return
	end
	local now = os.clock()
	combo = if now - comboAt < 0.6 then combo + 1 else 0
	comboAt = now
	play("Gem", 1 + math.min(combo, 12) * 0.04)
end)

-- The offer is re-sent for rerolls and queued level-ups at the same level; only a new level gets the fanfare.
local shownLevel = 0
Shared:WaitForChild("RunLevelUp").OnClientEvent:Connect(function(_cards, _rerolls, level: number)
	if level > shownLevel then
		play("LevelUp")
	else
		play("Reroll")
	end
	shownLevel = level
end)

Shared:WaitForChild("RunOver").OnClientEvent:Connect(function()
	shownLevel = 0
	play("GameOver")
end)

local function watchHealth(character: Model)
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	local last = hum.Health
	hum.HealthChanged:Connect(function(health)
		if health < last then
			play("Hurt")
		end
		last = health
	end)
end
me.CharacterAdded:Connect(watchHealth)
if me.Character then
	watchHealth(me.Character)
end
