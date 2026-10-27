-- PlayerSword (LocalScript, StarterPlayer.StarterPlayerScripts), GAME-35
-- Every player whose run has the sword (RunLoadout "sword=N") holds ReplicatedStorage.Swords.Sword_PhaseN (N capped at
-- 5) in the right hand; each client draws it for every character. The local character also plays the sword set:
-- SwordRun moving (dragged behind); on stopping, SwordHold (still trailing) for HOLD_TIME, then SwordPlant into SwordIdle
-- (planted beside the right foot); moving off from there plays SwordPull. Each transition ends on its loop's first
-- frame, so the loop waits there until it finishes; run <-> hold just cross-fade.
-- Animation ids go in ANIMS once published; until then Studio plays the KeyframeSequences in
-- ReplicatedStorage.SwordAnims (RegisterAnimationClip only works in Studio).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ANIMS = { SwordIdle = "", SwordRun = "", SwordHold = "", SwordPlant = "", SwordPull = "" } -- "rbxassetid://..." once published
-- The grip centre on RightHand, blade forward, flat sideways: the rest pose of scripts/18_r15_anims.py
local HAND_GRIP = CFrame.fromMatrix(Vector3.new(0, -0.158, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1))
local RUN_SPEED = 16 -- SwordRun is paced for this WalkSpeed
local HOLD_TIME = 5 -- seconds standing still with the sword trailing (SwordHold) before planting it

local swords = ReplicatedStorage:WaitForChild("Swords")
local me = Players.LocalPlayer
local scraping = {} -- held sword -> { tip = blade length from the grip, emitter, attachment }

-- Sparks where a dragged tip scrapes the ground: streaks thrown back and up, falling, hot orange to red.
-- The streak is BeamTexture40 from the VFX Studio plugin library (a long diamond), flying lengthwise.
local SPARKS = Instance.new("ParticleEmitter")
SPARKS.Texture = "rbxassetid://5320460025"
SPARKS.Orientation = Enum.ParticleOrientation.VelocityParallel
SPARKS.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 110)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 110, 30)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 25, 15)),
})
SPARKS.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.04) })
SPARKS.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
SPARKS.LightEmission, SPARKS.LightInfluence, SPARKS.Brightness = 0.8, 0, 2 -- brighter washes the streaks into a white blob
SPARKS.Lifetime, SPARKS.Speed = NumberRange.new(0.2, 0.45), NumberRange.new(9, 17)
SPARKS.SpreadAngle, SPARKS.Acceleration, SPARKS.Drag = Vector2.new(35, 35), Vector3.new(0, -50, 0), 3
SPARKS.ZOffset = 0.5
SPARKS.Enabled = false

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
	-- blade length: in ReplicatedStorage.Swords the grip sits unrotated and the blade runs up +Y
	local tip = 0
	for _, part in held:GetDescendants() do
		if part:IsA("BasePart") then
			tip = math.max(tip, part.Position.Y - held.PrimaryPart.Position.Y + part.Size.Y / 2)
		end
	end
	held.Name = "HeldSword"
	held:SetAttribute("Model", name)
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1, weld.C0 = hand, held.PrimaryPart, HAND_GRIP
	weld.Parent = held.PrimaryPart
	held.Parent = char
	local attachment = Instance.new("Attachment") -- in Terrain so it can face away from the run, not along the blade
	attachment.Parent = workspace.Terrain
	local emitter = SPARKS:Clone()
	emitter.Rate = 40 + 15 * math.clamp(level, 1, 5)
	emitter.Parent = attachment
	scraping[held] = { tip = tip, emitter = emitter, attachment = attachment }
end

RunService.Heartbeat:Connect(function()
	for held, fx in scraping do
		local char = held.Parent
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (hum and root) then
			fx.attachment:Destroy()
			scraping[held] = nil
			continue
		end
		local tip = held.PrimaryPart.CFrame:PointToWorldSpace(Vector3.new(0, fx.tip, 0))
		local ground = root.Position.Y - hum.HipHeight - root.Size.Y / 2
		local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		-- dragging: moving with the tip at the ground. Planted it is 2 studs under, raised well above; avatars smaller
		-- than the default R15 sink a dragged tip up to half a stud, hence the lopsided window.
		local depth = tip.Y - ground
		local on = velocity.Magnitude > 4 and depth > -1 and depth < 0.6
		fx.emitter.Enabled = on
		if on then
			local back = -velocity.Unit
			fx.attachment.WorldCFrame = CFrame.fromMatrix(Vector3.new(tip.X, ground + 0.05, tip.Z), back:Cross(Vector3.yAxis), (back + Vector3.yAxis * 0.8).Unit)
		end
	end
end)

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
	for _, name in { "SwordIdle", "SwordRun", "SwordHold" } do
		t[name].Priority = Enum.AnimationPriority.Action
	end
	t.SwordPull.Priority, t.SwordPlant.Priority = Enum.AnimationPriority.Action2, Enum.AnimationPriority.Action2
	local LOOPS = { idle = t.SwordIdle, run = t.SwordRun, hold = t.SwordHold }
	local state, busy, stoppedAt = nil, nil, 0 -- busy: the transition playing, if any

	local function enter(new, transition)
		for name, track in LOOPS do
			if name ~= new then
				track:Stop(0.2)
			end
		end
		t.SwordPull:Stop(0.1)
		t.SwordPlant:Stop(0.1)
		LOOPS[new]:Play(0.2)
		LOOPS[new].TimePosition = 0
		busy = transition
		if busy then
			busy:Play(0.1)
		end
		state = new
	end

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
			state, busy = nil, nil
			return
		end
		local moving = hum.MoveDirection.Magnitude > 0.1
		if not state then -- just spawned or armed: no transition
			enter(moving and "run" or "idle")
		elseif moving and state ~= "run" then
			enter("run", state == "idle" and t.SwordPull or nil) -- from hold the sword is already trailing
		elseif not moving and state == "run" then
			enter("hold")
			stoppedAt = os.clock()
		elseif state == "hold" and os.clock() - stoppedAt >= HOLD_TIME then
			enter("idle", t.SwordPlant)
		end
		if busy and not busy.IsPlaying then
			busy = nil
		end
		LOOPS[state]:AdjustSpeed(if busy then 0 elseif state == "run" then math.max(hum.WalkSpeed, 1) / RUN_SPEED else 1)
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
