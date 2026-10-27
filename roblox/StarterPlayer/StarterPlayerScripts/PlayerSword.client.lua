-- PlayerSword (LocalScript, StarterPlayer.StarterPlayerScripts), GAME-35
-- Every player whose run has the sword (RunLoadout "sword=N") holds ReplicatedStorage.Swords.Sword_PhaseN (N capped at
-- 5) in the right hand; each client draws it for every character. The local character also plays the sword set:
-- SwordIdle standing (the sword planted beside the right foot), SwordRun moving (dragged behind), SwordPull / SwordPlant
-- in between; each transition ends on its loop's first frame, so the loop waits there until it finishes.
-- Animation ids go in ANIMS once published; until then Studio plays the KeyframeSequences in
-- ReplicatedStorage.SwordAnims (RegisterAnimationClip only works in Studio).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ANIMS = { SwordIdle = "", SwordRun = "", SwordPlant = "", SwordPull = "" } -- "rbxassetid://..." once published
-- The grip centre on RightHand, blade forward, flat sideways: the rest pose of scripts/18_r15_anims.py
local HAND_GRIP = CFrame.fromMatrix(Vector3.new(0, -0.158, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1))
local RUN_SPEED = 16 -- SwordRun is paced for this WalkSpeed

local swords = ReplicatedStorage:WaitForChild("Swords")
local me = Players.LocalPlayer

local function swordLevel(player: Player): number?
	return tonumber(string.match(player:GetAttribute("RunLoadout") or "", "sword=(%d+)"))
end

local function hold(player: Player)
	local char = player.Character
	local hand = char and char:FindFirstChild("RightHand")
	if not hand then
		return
	end
	local level = swordLevel(player)
	local name = level and "Sword_Phase" .. math.clamp(level, 1, 5)
	local held = char:FindFirstChild("HeldSword")
	if held and held:GetAttribute("Model") == name then
		return
	end
	if held then
		held:Destroy()
	end
	if not name then
		return
	end
	held = swords[name]:Clone()
	held.Name = "HeldSword"
	held:SetAttribute("Model", name)
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1, weld.C0 = hand, held.PrimaryPart, HAND_GRIP
	weld.Parent = held.PrimaryPart
	held.Parent = char
end

local function clip(name: string): Animation?
	local id = ANIMS[name]
	if id == "" then
		if not RunService:IsStudio() then
			return nil
		end
		id = game:GetService("AnimationClipProvider"):RegisterAnimationClip(ReplicatedStorage.SwordAnims[name])
	end
	local a = Instance.new("Animation")
	a.AnimationId = id
	return a
end

local function animate(char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	local animator = hum:WaitForChild("Animator") :: Animator
	local t = {}
	for name in ANIMS do
		local a = clip(name)
		if not a then
			return
		end
		t[name] = animator:LoadAnimation(a)
	end
	-- above the place's own Idle / Movement clips, which would otherwise blend in at equal priority
	t.SwordIdle.Priority, t.SwordRun.Priority = Enum.AnimationPriority.Action, Enum.AnimationPriority.Action
	t.SwordPull.Priority, t.SwordPlant.Priority = Enum.AnimationPriority.Action2, Enum.AnimationPriority.Action2
	local moving, busy = nil, nil -- busy: the transition playing, if any
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not char.Parent then
			conn:Disconnect()
			return
		end
		if not swordLevel(me) then
			for _, track in t do
				if track.IsPlaying then
					track:Stop(0.2)
				end
			end
			moving, busy = nil, nil
			return
		end
		local now = hum.MoveDirection.Magnitude > 0.1
		if now ~= moving then
			local loop, other = t.SwordIdle, t.SwordRun
			if now then
				loop, other = other, loop
			end
			other:Stop(0.15)
			t.SwordPull:Stop(0.1)
			t.SwordPlant:Stop(0.1)
			loop:Play(0.15)
			loop.TimePosition = 0
			busy = nil
			if moving ~= nil then -- not the first pose after spawning or arming
				busy = now and t.SwordPull or t.SwordPlant
				busy:Play(0.1)
			end
			moving = now
		end
		if busy and not busy.IsPlaying then
			busy = nil
		end
		local loop = moving and t.SwordRun or t.SwordIdle
		loop:AdjustSpeed(if busy then 0 elseif moving then math.max(hum.WalkSpeed, 1) / RUN_SPEED else 1)
	end)
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("RunLoadout"):Connect(function()
		hold(player)
	end)
	local function spawned(char)
		char:WaitForChild("RightHand")
		hold(player)
		if player == me then
			animate(char)
		end
	end
	player.CharacterAdded:Connect(spawned)
	if player.Character then
		task.spawn(spawned, player.Character)
	end
end

Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end
