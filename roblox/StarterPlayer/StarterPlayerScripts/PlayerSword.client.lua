-- PlayerSword (LocalScript, StarterPlayer.StarterPlayerScripts), GAME-35
-- Every player whose run has the sword (RunLoadout "sword=N") holds ReplicatedStorage.Swords.Sword_PhaseN (N capped at
-- 5) in the right hand; each client draws it for every character. The local character also plays the sword set:
-- SwordRun moving (dragged behind); on stopping, SwordHold (still trailing) for HOLD_TIME, then SwordPlant into SwordIdle
-- (planted beside the right foot); moving off from there plays SwordPull. Each transition ends on its loop's first
-- frame, so the loop waits there until it finishes; run <-> hold just cross-fade. A dash (GAME-44) plays SwordDashF/B/L/R.
-- Animation ids go in ANIMS once published; until then Studio plays the KeyframeSequences in
-- ReplicatedStorage.SwordAnims (RegisterAnimationClip only works in Studio).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ANIMS = { SwordIdle = "", SwordRun = "", SwordHold = "", SwordPlant = "", SwordPull = "", -- "rbxassetid://..." once published
	SwordDashF = "", SwordDashB = "", SwordDashL = "", SwordDashR = "" }
local DASH_LENGTH = 0.4 -- SwordDash* are 12 frames at 30 fps
-- The grip centre on RightHand, blade forward, flat sideways: the rest pose of scripts/18_r15_anims.py
local HAND_GRIP = CFrame.fromMatrix(Vector3.new(0, -0.158, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1))
local RUN_SPEED = 16 -- SwordRun is paced for this WalkSpeed
local HOLD_TIME = 5 -- seconds standing still with the sword trailing (SwordHold) before planting it

local swords = ReplicatedStorage:WaitForChild("Swords")
-- The new default set: the owner's Meshy shadow blades (scripts/22_sword_brick.py prepares each GLB), one Sword_PhaseN
-- per phase as they arrive. Phases it doesn't have yet come from Swords, the old black/red set that stays as a skin.
local SET = "SwordsShadow"
local me = Players.LocalPlayer

local function swordModel(name: string): Model
	local set = ReplicatedStorage:FindFirstChild(SET)
	return set and set:FindFirstChild(name) or swords[name]
end

local function swordLevel(player: Player): number?
	return tonumber(string.match(player:GetAttribute("RunLoadout") or "", "sword=(%d+)"))
		or (if player:GetAttribute("DashPractice") then 5 else nil) -- the dash practice field lends a sword (GAME-44)
end

-- A sword picked up from the showcase gallery (this client only); it wins over the run's sword until dropped.
local picked: Model? = nil

local function hold(player: Player)
	local char = player.Character
	local hand = char and char:FindFirstChild("RightHand")
	if not hand then
		return
	end
	local level = swordLevel(player)
	local src = if player == me and picked then picked elseif level then swordModel("Sword_Phase" .. math.clamp(level, 1, 5)) else nil
	local name = src and src:GetFullName()
	local held = char:FindFirstChild("HeldSword")
	if held and held:GetAttribute("Model") == name then
		return
	end
	if held then
		held:Destroy()
	end
	if not src then
		return
	end
	held = src:Clone()
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
		char:SetAttribute("SwordState", new) -- GoblinSFX plays the pull / drag / plant sounds from it
	end

	-- GAME-44: a dash plays SwordDashF/B/L/R by where it goes relative to where the body faces (the server keeps that
	-- facing through the dash, so side and back dashes are sidesteps / back hops). From the planted idle the sword comes
	-- out into the trailing hold. The track fades out just before its end into the loop underneath.
	for _, d in { "F", "B", "L", "R" } do
		t["SwordDash" .. d].Priority = Enum.AnimationPriority.Action4
	end
	local dashConn
	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild("Goblin"):WaitForChild("RunDash")
		if not char.Parent then
			return
		end
		dashConn = remote.OnClientEvent:Connect(function(action, player, _, dir, _, face)
			if action ~= "start" or player ~= me or not state or typeof(dir) ~= "Vector3" then
				return
			end
			face = if typeof(face) == "Vector3" then face else dir
			local ahead, side = dir:Dot(face), dir:Dot(face:Cross(Vector3.yAxis))
			local which = if math.abs(ahead) >= math.abs(side) then (if ahead >= 0 then "F" else "B")
				else (if side > 0 then "R" else "L")
			if state == "idle" then
				enter("hold")
				stoppedAt = os.clock()
			end
			local track = t["SwordDash" .. which]
			track:Play(0.05)
			task.delay(DASH_LENGTH - 0.12, function()
				if track.IsPlaying then
					track:Stop(0.12)
				end
			end)
		end)
	end)

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not char.Parent then
			conn:Disconnect()
			if dashConn then
				dashConn:Disconnect()
			end
			return
		end
		if not (picked or swordLevel(me)) then
			for _, track in t do
				if track.IsPlaying then
					track:Stop(0.2)
				end
			end
			if state then
				char:SetAttribute("SwordState", nil)
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
	for _, attr in { "RunLoadout", "DashPractice" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			hold(player)
		end)
	end
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

-- Showcase gallery (SwordFXZone, BuildSwordFXZone.luau): stepping onto a stand (StandA1..5 = SwordsShadow, StandB1..5 =
-- Swords) picks up that stand's Sword_PhaseN; the GalleryClear pad or the start of a run drops it again.
local GALLERY = { A = "SwordsShadow", B = "Swords" }
local function pick(src: Model?)
	if picked ~= src then
		picked = src
		hold(me)
	end
end
me:GetAttributeChangedSignal("RunStart"):Connect(function()
	pick(nil)
end)
RunService.Heartbeat:Connect(function()
	local zone = workspace:FindFirstChild("SwordFXZone")
	local root = zone and me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local function on(part: BasePart?, reach: number): boolean
		return part ~= nil and Vector2.new(root.Position.X - part.Position.X, root.Position.Z - part.Position.Z).Magnitude < reach
	end
	if on(zone:FindFirstChild("GalleryClear"), 3) then
		pick(nil)
		return
	end
	for row, setName in GALLERY do
		local set = ReplicatedStorage:FindFirstChild(setName)
		for n = 1, 5 do
			local src = set and set:FindFirstChild("Sword_Phase" .. n)
			if src and on(zone:FindFirstChild("Stand" .. row .. n), 1.8) then
				pick(src)
			end
		end
	end
end)
