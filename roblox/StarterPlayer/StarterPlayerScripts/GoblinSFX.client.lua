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
	if def.Id == "" then
		continue -- not uploaded yet
	end
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

local lastSlash = 0
Shared:WaitForChild("HordeFx").OnClientEvent:Connect(function(kind: string, ...)
	local args = { ... }
	if kind == "slash" and args[1] == me then
		lastSlash = os.clock()
		play("Slash", 0.95 + swordLevel() * 0.04) -- a little brighter with each sword level
		if swordLevel() >= 4 then
			play("SwordWave") -- the shockwave ring (GoblinHordeClient SLASH_TIERS `wave`)
		end
	elseif kind == "fire" and args[7] == me then
		play("Fireball")
	end
end)

-- HordeHits only reaches the player who landed them. Hits carry no weapon: the ones right after our slash are the
-- sword's (as in GoblinHordeClient's impact), and get the heavier hit.
Shared:WaitForChild("HordeHits").OnClientEvent:Connect(function()
	play(if os.clock() - lastSlash < 0.35 then "SwordHit" else "Hit")
end)

-- The held sword (PlayerSword sets the character's SwordState): pulled out of the ground when a run starts from idle,
-- scraping along while running, slammed in when it plants (the slam lands ~0.35 s into SwordPlant).
local drag = templates.SwordDrag
drag.Looped = true
local function watchSword(character: Model)
	drag:Stop() -- a respawn mid-run
	local last: string? = nil
	character:GetAttributeChangedSignal("SwordState"):Connect(function()
		local state = character:GetAttribute("SwordState")
		if state == "run" and last == "idle" then
			play("SwordPull")
		elseif state == "idle" and last == "hold" then
			task.delay(0.35, play, "SwordPlant")
		end
		if state == "run" then
			drag:Play()
		else
			drag:Stop()
		end
		last = state
	end)
end
me.CharacterAdded:Connect(watchSword)
if me.Character then
	watchSword(me.Character)
end

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

-- Music (GAME-38): the lobby loop while out of a run, the run loop while in one (the server sets RunStart for the
-- run's length), cross-faded; a faded-out track stops so it doesn't keep streaming.
local MUSIC_FADE = 1.5
local function music()
	local inRun = me:GetAttribute("RunStart") ~= nil
	for name, on in { LobbyMusic = not inRun, RunMusic = inRun } do
		local s = templates[name]
		if not s then
			continue
		end
		s.Looped = true
		if on and not s.IsPlaying then
			s.Volume = 0
			s:Play()
		end
		local fade = game:GetService("TweenService"):Create(s, TweenInfo.new(MUSIC_FADE), { Volume = if on then Sounds[name].Volume else 0 })
		fade.Completed:Once(function()
			if not on and s.Volume == 0 then
				s:Stop()
			end
		end)
		fade:Play()
	end
end
me:GetAttributeChangedSignal("RunStart"):Connect(music)
music()
